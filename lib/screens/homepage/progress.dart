import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Progress extends StatefulWidget {
  const Progress({super.key});

  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final FlutterTts _tts = FlutterTts();
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _announce();
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    // Don’t await completion — we want speech to run independently
    await _tts.awaitSpeakCompletion(false);
  }

  /// Always announce entering the Progress screen
  Future<void> _announce() async {
    try {
      await _tts.stop(); // Clean start
      await _tts.speak('You are now in the Progress screen.');
    } catch (_) {}
  }

  /// Handle back press or close button
  Future<bool> _onWillPop() async {
    if (_isClosing) return false;
    _isClosing = true;

    try {
      // Stop any ongoing announcement first
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      // Speak closing announcement *without waiting*
      _tts.speak('Progress screen closed.');
    } catch (_) {}

    // 🔥 Immediately navigate back
    if (mounted) {
      Navigator.of(context).pop();
    }

    return false; // Prevent double pop
  }

  @override
  void dispose() {
    // Don’t stop TTS — allow the closing announcement to finish naturally
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onWillPop, // ✅ Tap behaves like back button
          ),
        ),
        body: const Center(
          child: Text(
            'This is the Progress screen.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
