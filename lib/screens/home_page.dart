import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '/screens/homepage/read_notes.dart';
import '/screens/homepage/ask_questions.dart';
import '/screens/homepage/start_quiz.dart';
import '/screens/homepage/progress.dart';
import '/screens/homepage/upload_notes.dart';
import '/widgets/voice_command_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.7);
  }

  Future<void> _speak(String message) async {
    await _flutterTts.stop(); // stop any previous speech
    await _flutterTts.speak(message);
  }

  void _showInfo(String title, String subtitle) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $subtitle'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resumeListening() {
    // Resumes voice recognition if returning to HomePage
    if (mounted) {
      setState(() {}); // triggers rebuild for VoiceCommandButton to re-init
    }
  }

  void _onReadNotes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReadNotesScreen()),
    );
    _resumeListening();
  }

  void _onAskQuestion() async {
    await AskQuestionsPopup.show(context);
    _resumeListening();
  }

  void _onStartQuiz() async {
    await StartQuiz.show(context);
    _resumeListening();
  }

  void _onProgress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Progress()),
    );
    _resumeListening();
  }

  void _onUploadNotes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadNotes()),
    );
    _resumeListening();
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.blueAccent,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 26, color: Colors.white),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenEar'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    const message =
                        'OpenEar — voice-first learning for visually impaired learners. Main actions: Read Notes, Ask Question, Start Quiz, Progress, Upload / Add Notes.';
                    _showInfo(
                      'Welcome',
                      'Main actions: Read Notes, Ask Question, Start Quiz, Progress, Upload / Add Notes.',
                    );
                    _speak(message);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'OpenEar — voice-first learning for visually impaired learners.\nTap to hear main actions.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildActionButton(
                  label: 'Read Notes',
                  icon: Icons.record_voice_over,
                  onPressed: _onReadNotes,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Ask Question (Voice)',
                  icon: Icons.mic,
                  onPressed: _onAskQuestion,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Start Quiz',
                  icon: Icons.quiz,
                  onPressed: _onStartQuiz,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Progress',
                  icon: Icons.insert_chart,
                  onPressed: _onProgress,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Upload / Add Notes',
                  icon: Icons.upload_file,
                  onPressed: _onUploadNotes,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 24),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VoiceCommandButton(
                      onCommandRecognized: (command) {
                        switch (command) {
                          case 'read_notes':
                            _onReadNotes();
                            break;
                          case 'ask_questions':
                            _onAskQuestion();
                            break;
                          case 'start_quiz':
                            _onStartQuiz();
                            break;
                          case 'progress':
                            _onProgress();
                            break;
                          case 'upload_notes':
                            _onUploadNotes();
                            break;
                        }
                      },
                      speak: _speak,
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _showInfo(
                        'Help',
                        'Say "help" — voice commands will be added later.',
                      ),
                      icon: const Icon(Icons.help_outline, size: 20),
                      label: const Text('Help'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
