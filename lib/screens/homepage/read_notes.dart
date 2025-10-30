import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReadNotesScreen extends StatefulWidget {
  const ReadNotesScreen({super.key});

  @override
  State<ReadNotesScreen> createState() => _ReadNotesScreenState();
}

class _ReadNotesScreenState extends State<ReadNotesScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _hasAnnounced = false; // ✅ Prevent repeated announcement
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  Future<void> _announce() async {
    if (_hasAnnounced || _isSpeaking) return;
    _isSpeaking = true;
    _hasAnnounced = true;

    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.awaitSpeakCompletion(true);

    await _tts.speak('You are now in the Read Notes screen.');

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> notes = [
      'Note 1: Introduction to Voice-First Learning',
      'Note 2: Importance of Accessibility in Education',
      'Note 3: Using OpenEar for Interactive Learning',
      'Note 4: Review and Summary',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Notes'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: notes.isEmpty
              ? const Center(
                  child: Text(
                    'No notes available. Upload or add new notes first.',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Card(
                      color: Colors.teal.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          note,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.volume_up,
                          color: Colors.white,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Playing: ${note.split(":").first}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
