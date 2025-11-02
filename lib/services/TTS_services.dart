import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';

/// A singleton TTS service used by all screens.
/// Keeps one engine alive to prevent interruptions during navigation.
class TtsService {
  // Singleton instance
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  TtsService._internal() {
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    // Optional: Prevents TTS engine from getting stuck between screens
    await _tts.setQueueMode(1); // 1 = queue; 0 = flush
  }

  /// Speaks text and waits until finished.
  Future<void> speakAndWait(String message) async {
    if (message.trim().isEmpty) return;
    await _init();
    await _tts.stop();
    await _tts.speak(message);
  }

  /// Speaks text *without waiting* (fire and forget).
  Future<void> speak(String message) async {
    if (message.trim().isEmpty) return;
    await _init();
    await _tts.stop();
    await _tts.speak(message);
  }

  /// Stops current speech immediately.
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Smoothly speaks a closing message, waits, and pops safely.
  Future<void> speakAndPop(BuildContext context, String message) async {
    await speakAndWait(message);
    await Future.delayed(
      const Duration(milliseconds: 150),
    ); // allow playback to stabilize
    if (context.mounted) Navigator.of(context).pop();
  }
}
