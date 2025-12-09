import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '/services/TTS_services.dart';
import '/services/question_generator.dart';

class QuizPlayerScreen extends StatefulWidget {
  final String title;
  final String content;
  final int maxQuestions;

  const QuizPlayerScreen({
    required this.title,
    required this.content,
    this.maxQuestions = 5,
    super.key,
  });

  @override
  State<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QuizPlayerScreenState extends State<QuizPlayerScreen> {
  final TtsService tts = TtsService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  late List<QuizQuestion> questions;
  int currentQuestionIndex = 0;
  int score = 0;
  bool _listening = false;
  String _heardText = '';
  bool _answered = false;
  String? _selectedAnswer;
  late QuizQuestion currentQuestion;

  final List<String> answerLabels = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    // Generate questions from content
    questions = QuestionGenerator.generateQuestions(
      widget.content,
      widget.title,
      maxQuestions: widget.maxQuestions,
    );

    if (questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate quiz questions')),
        );
        Navigator.pop(context);
      }
      return;
    }

    currentQuestion = questions[0];
    await _announceQuestion();
  }

  Future<void> _announceQuestion() async {
    await tts.stop();
    final questionNum = currentQuestionIndex + 1;
    final totalQuestions = questions.length;

    // Announce question number and content
    await tts.speakAndWait(
      'Question $questionNum of $totalQuestions: ${currentQuestion.question}',
    );

    // Announce each option
    for (int i = 0; i < currentQuestion.options.length; i++) {
      await tts.speakAndWait(
        '${answerLabels[i]}: ${currentQuestion.options[i]}',
      );
    }

    await tts.speakAndWait('Please select your answer by pressing A, B, C, or D, or say your answer.');
  }

  Future<void> _startListening() async {
    if (_listening) return;

    final available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
    );

    if (!available) {
      await tts.speak('Speech recognition not available');
      return;
    }

    setState(() => _listening = true);
    _heardText = '';

    _speech.listen(
      onResult: (result) {
        setState(() {
          _heardText = result.recognizedWords.toLowerCase();
        });

        if (result.finalResult) {
          _processVoiceAnswer(_heardText);
        }
      },
      localeId: 'en_US',
    );

    await tts.speak('Listening for your answer...');
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _listening = false);
  }

  void _selectAnswer(int index) {
    if (_answered) return;

    setState(() {
      _selectedAnswer = currentQuestion.options[index];
    });

    final selectedOption = currentQuestion.options[index];
    _processAnswer(selectedOption, answerLabels[index]);
  }

  Future<void> _processVoiceAnswer(String answer) async {
    await _stopListening();

    if (answer.isEmpty) {
      await tts.speak('No answer detected. Please try again.');
      return;
    }

    // Try to match voice answer to one of the options or labels
    int selectedIndex = -1;
    final answerClean = answer.trim().toLowerCase();

    // Check if they said A, B, C, or D (with more flexible matching)
    if (answerClean.contains('a') || answerClean == 'a' || answerClean.contains('option a')) {
      selectedIndex = 0;
    } else if (answerClean.contains('b') || answerClean == 'b' || answerClean.contains('option b')) {
      selectedIndex = 1;
    } else if (answerClean.contains('c') || answerClean == 'c' || answerClean.contains('option c')) {
      selectedIndex = 2;
    } else if (answerClean.contains('d') || answerClean == 'd' || answerClean.contains('option d')) {
      selectedIndex = 3;
    }

    // Check if they said one of the options
    if (selectedIndex == -1) {
      for (int i = 0; i < currentQuestion.options.length; i++) {
        final option = currentQuestion.options[i].toLowerCase();
        // Check for substantial overlap
        final words = option.split(' ');
        int matchCount = 0;
        for (final word in words) {
          if (word.length > 3 && answerClean.contains(word)) {
            matchCount++;
          }
        }
        if (matchCount >= 2 || (words.length == 1 && answerClean.contains(option))) {
          selectedIndex = i;
          break;
        }
      }
    }

    if (selectedIndex == -1) {
      await tts.speak('Could not match your answer. Please say A, B, C, or D, or use the buttons.');
      return;
    }

    final selectedOption = currentQuestion.options[selectedIndex];
    _processAnswer(selectedOption, answerLabels[selectedIndex]);
  }

  Future<void> _processAnswer(String selectedOption, String label) async {
    if (_answered) return; // Prevent duplicate submissions

    setState(() {
      _answered = true;
      _selectedAnswer = selectedOption;
    });

    // Check correctness
    final isCorrect = selectedOption.toLowerCase() == currentQuestion.correctAnswer.toLowerCase();

    if (isCorrect) {
      score++;
      await tts.speak('Correct! You got a point.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Correct!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final correctLabel = answerLabels[currentQuestion.correctIndex];
      await tts.speak(
        'Incorrect. The correct answer is $correctLabel: ${currentQuestion.options[currentQuestion.correctIndex]}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Incorrect. Correct answer is $correctLabel: ${currentQuestion.options[currentQuestion.correctIndex]}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Move to next question or show results
    await Future.delayed(const Duration(seconds: 3));

    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _answered = false;
        _heardText = '';
        _selectedAnswer = null;
        currentQuestion = questions[currentQuestionIndex];
      });
      await _announceQuestion();
    } else {
      _showResults();
    }
  }

  Future<void> _showResults() async {
    final percentage = ((score / questions.length) * 100).toStringAsFixed(0);
    final resultMessage =
        'Quiz complete! You scored $score out of ${questions.length}, which is $percentage percent.';

    await _saveProgress(score, questions.length, int.parse(percentage));
    await tts.speak(resultMessage);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Quiz Results',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score / ${questions.length}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _getResultMessage(int.parse(percentage)),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    }
  }

  String _getResultMessage(int percentage) {
    if (percentage >= 80) {
      return 'Excellent! You mastered this content! 🎉';
    } else if (percentage >= 60) {
      return 'Good job! You understand most of the content. 👍';
    } else if (percentage >= 40) {
      return 'Fair effort. Review the content and try again. 📖';
    } else {
      return 'Keep practicing! You can improve next time. 💪';
    }
  }

  Future<void> _saveProgress(int score, int total, int percent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> existing = [];
      final raw = prefs.getString('quiz_progress');
      if (raw != null) {
        existing = jsonDecode(raw) as List<dynamic>;
      }

      existing.insert(0, {
        'title': widget.title,
        'score': score,
        'total': total,
        'percent': percent,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (existing.length > 50) {
        existing = existing.take(50).toList();
      }

      await prefs.setString('quiz_progress', jsonEncode(existing));
    } catch (e) {
      debugPrint('Failed to save progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          tts.stop();
          _speech.stop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Quiz: ${widget.title}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: Colors.deepPurpleAccent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (currentQuestionIndex + 1) / questions.length,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation(Colors.deepPurpleAccent),
              ),
              const SizedBox(height: 20),

              // Question number
              Text(
                'Question ${currentQuestionIndex + 1} of ${questions.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Question text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.deepPurpleAccent, width: 2),
                ),
                child: Text(
                  currentQuestion.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Answer options (A, B, C, D)
              ...List.generate(
                currentQuestion.options.length,
                (index) {
                  final option = currentQuestion.options[index];
                  final label = answerLabels[index];
                  final isSelected = _selectedAnswer == option;
                  final isCorrect = option == currentQuestion.options[currentQuestion.correctIndex];
                  
                  // Vibrant colors for each choice
                  final List<Color> choiceColors = [
                    Colors.blue.shade600,      // A - Blue
                    Colors.orange.shade600,    // B - Orange
                    Colors.purple.shade600,    // C - Purple
                    Colors.teal.shade600,      // D - Teal
                  ];
                  final choiceColor = choiceColors[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: GestureDetector(
                      onTap: _answered ? null : () => _selectAnswer(index),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? (isCorrect ? Colors.green.shade700 : Colors.red.shade700)
                                : choiceColor,
                            width: isSelected ? 4 : 3,
                          ),
                          color: isSelected
                              ? (isCorrect
                                  ? Colors.green.shade50
                                  : Colors.red.shade50)
                              : choiceColor.withOpacity(0.08),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected 
                                ? (isCorrect ? Colors.green : Colors.red).withOpacity(0.3)
                                : choiceColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 65,
                              height: 65,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? (isCorrect ? Colors.green.shade600 : Colors.red.shade600)
                                    : choiceColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                      ? (isCorrect ? Colors.green : Colors.red).withOpacity(0.4)
                                      : choiceColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isSelected
                                      ? (isCorrect ? Colors.green.shade800 : Colors.red.shade800)
                                      : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (isSelected && _answered)
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green.shade600 : Colors.red.shade600,
                                size: 36,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Voice input section
              if (!_answered) ...[
                Text(
                  'Or use voice input:',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _listening ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _listening ? _stopListening : _startListening,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(
                    _listening ? 'Stop Listening' : 'Say Your Answer',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],

              // Heard text display
              if (_heardText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.amber[50],
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Text(
                      'Heard: "$_heardText"',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

              // Next button
              if (_answered)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: currentQuestionIndex < questions.length - 1
                        ? () {
                            setState(() {
                              currentQuestionIndex++;
                              _answered = false;
                              _heardText = '';
                              _selectedAnswer = null;
                              currentQuestion = questions[currentQuestionIndex];
                            });
                            _announceQuestion();
                          }
                        : () => _showResults(),
                    child: Text(
                      currentQuestionIndex < questions.length - 1 ? 'Next Question' : 'Show Results',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    tts.stop();
    super.dispose();
  }
}
