import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Progress extends StatefulWidget {
  const Progress({super.key});

  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final FlutterTts _tts = FlutterTts();
  static bool _hasSpoken = false; // Prevent duplicate announcements

  @override
  void initState() {
    super.initState();
    _announce();
  }

  Future<void> _announce() async {
    if (_hasSpoken) return;
    _hasSpoken = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.stop(); // Stop any previous TTS
    await _tts.speak('You are now in the Progress screen.');
  }

  @override
  void dispose() {
    _hasSpoken = false; // Reset for next navigation
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const Center(
        child: Text(
          'This is the Progress screen.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
