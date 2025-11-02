import 'package:flutter/material.dart';
import '/services/TTS_services.dart'; // ✅ Use shared TTS service

class Progress extends StatefulWidget {
  const Progress({super.key});

  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final TtsService tts = TtsService();
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  Future<void> _announce() async {
    await tts.stop();
    await tts.speakAndWait('You are now in the Progress screen.');
  }

  Future<bool> _onWillPop() async {
    if (_isClosing) return false;
    _isClosing = true;

    try {
      await tts.stop();
      await Future.delayed(const Duration(milliseconds: 150));
      await tts.speak('Closing Progress screen.');
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
    return false; // Prevent double pop
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
            onPressed: _onWillPop,
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
