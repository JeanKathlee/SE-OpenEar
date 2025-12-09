import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '/services/TTS_services.dart';
import '/services/question_generator.dart';
import 'quiz_player.dart';

class StartQuizScreen extends StatefulWidget {
  const StartQuizScreen({super.key});

  @override
  State<StartQuizScreen> createState() => _StartQuizScreenState();
}

class _StartQuizScreenState extends State<StartQuizScreen> {
  static const int _maxQuestions = 20;
  final TtsService tts = TtsService();
  List<Map<String, dynamic>> quizzableNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzableNotes();
    _announceEntry();
  }

  Future<void> _announceEntry() async {
    await tts.stop();
    await tts.speakAndWait('You are now in the Start Quiz screen. Select a file to start the quiz.');
  }

  Future<void> _loadQuizzableNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('openear_saved_notes');

      if (notesJson != null && notesJson.isNotEmpty) {
        final decoded = jsonDecode(notesJson);
        if (decoded is List) {
          final allNotes = decoded.cast<Map<String, dynamic>>();
          // Filter only quizzable notes and compute question counts up front
          final quizzable = allNotes
              .where((note) => (note['isQuizzable'] as bool?) ?? false)
              .map((note) {
                final title = (note['title'] ?? 'Untitled').toString();
                final content = (note['content'] ?? '').toString();
                final questionCount = QuestionGenerator.generateQuestions(
                  content,
                  title,
                  maxQuestions: _maxQuestions,
                ).length;
                return {
                  ...note,
                  'questionCount': questionCount,
                };
              })
              .toList();

          setState(() {
            quizzableNotes = quizzable;
            isLoading = false;
          });

          if (quizzable.isEmpty) {
            await tts.speak('No quizzable files found. Please upload educational content.');
          }
        }
      } else {
        setState(() {
          isLoading = false;
        });
        await tts.speak('No files found. Please upload files first.');
      }
    } catch (e) {
      debugPrint('Error loading quizzable notes: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _startQuiz(Map<String, dynamic> note) async {
    final title = (note['title'] ?? '').toString();
    final content = (note['content'] ?? '').toString();

    await tts.speak('Starting quiz for $title');

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPlayerScreen(
            title: title,
            content: content,
            maxQuestions: _maxQuestions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await tts.stop();
        await tts.speak('Closing Start Quiz screen');
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Start Quiz',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurpleAccent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : quizzableNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info, size: 64, color: Colors.grey),
                        const SizedBox(height: 20),
                        const Text(
                          'No quizzable files found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: quizzableNotes.length,
                    itemBuilder: (context, index) {
                      final note = quizzableNotes[index];
                      final title = (note['title'] ?? 'Untitled').toString();
                      final score = (note['quizzabilityScore'] as int?) ?? 0;
                      final questionCount = (note['questionCount'] as int?) ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: _getScoreColor(score),
                            child: Text(
                              questionCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            _getScoreLabel(score),
                            style: TextStyle(
                              color: _getDarkScoreColor(score),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () => _startQuiz(note),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getDarkScoreColor(int score) {
    if (score >= 80) return Colors.green.shade700;
    if (score >= 60) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent - Highly Quizzable';
    if (score >= 60) return 'Good - Suitable for Quiz';
    return 'Fair - Can be Quizzed';
  }
}
