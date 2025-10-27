import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _listening = false;

  void _showInfo(String title, String subtitle) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $subtitle'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onReadNotes() => _showInfo(
    'Read Notes',
    'Will read saved study materials (TTS added later).',
  );
  void _onAskQuestion() => _showInfo(
    'Ask Question',
    'Opens voice question input (STT added later).',
  );
  void _onStartQuiz() =>
      _showInfo('Start Quiz', 'Starts quiz flow (voice-driven).');
  void _onProgress() =>
      _showInfo('Progress', 'Shows saved quiz progress (CSV).');
  void _onUploadNotes() =>
      _showInfo('Upload Notes', 'Upload or paste study notes.');

  void _toggleListening() {
    setState(() => _listening = !_listening);
    _showInfo('Voice Mode', _listening ? 'Enabled' : 'Disabled');
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
                color: Colors.white, // high contrast label color
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor:
                Colors.white, // ensures icon + label are white on all platforms
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
          child: Column(
            children: [
              InkWell(
                onTap: () => _showInfo(
                  'Welcome',
                  'Main actions: Read Notes, Ask Question, Start Quiz, Progress.',
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'OpenEar — voice-first learning for visually impaired learners.\nTap to hear main actions.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors
                          .black87, // darker for good contrast on light background
                    ),
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
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _toggleListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _listening
                          ? Colors.redAccent
                          : Colors.blueAccent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                      foregroundColor: Colors.white,
                    ),
                    child: Icon(
                      _listening ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _showInfo(
                      'Help',
                      'Say "help" — voice commands will be added later.',
                    ),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Help'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
