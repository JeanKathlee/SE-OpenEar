import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecognitionService {
  // ✅ Singleton pattern
  static final VoiceRecognitionService _instance =
      VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _autoRestartAllowed = false;

  Function(String)? _onResultCallback;
  VoidCallback? onSilenceDetected;

  Timer? _listeningMonitor;
  DateTime? _lastHeardTime;

  /// ✅ Initialize only once per app lifecycle
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: $error');
      },
      onStatus: (status) async {
        debugPrint('Speech recognition status: $status');

        if (_autoRestartAllowed &&
            (status == 'notListening' || status == 'done') &&
            _onResultCallback != null) {
          // short delay before restarting
          await Future.delayed(const Duration(milliseconds: 2500));
          if (!_autoRestartAllowed) return;
          if (_speech.isListening) {
            debugPrint('Skipped restart: still listening');
            return;
          }

          debugPrint('Restarting after silence...');
          await startListening(_onResultCallback!, autoRestart: true);
        }
      },
    );

    debugPrint(
      _isInitialized
          ? 'Speech recognition initialized ✅'
          : 'Speech recognition failed ❌',
    );

    return _isInitialized;
  }

  /// ✅ Starts voice recognition and listens for text
  Future<void> startListening(
    Function(String) onResult, {
    bool autoRestart = false,
  }) async {
    // Stop any previous session before starting
    await stopListening();

    _onResultCallback = onResult;
    _autoRestartAllowed = autoRestart;

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        debugPrint('Speech recognition init failed.');
        return;
      }
    }

    debugPrint('🎤 Listening started...');
    _lastHeardTime = DateTime.now();

    await _speech.listen(
      onResult: (result) {
        final recognizedWords = result.recognizedWords.toLowerCase();
        if (recognizedWords.isNotEmpty) {
          _lastHeardTime = DateTime.now();
          debugPrint(
            '${result.finalResult ? "Final" : "Partial"} recognized: $recognizedWords',
          );
          onResult(recognizedWords);
        }
      },
      localeId: 'en_US',
      partialResults: true,
      listenMode: ListenMode.dictation,
    );

    _startListeningMonitor();
  }

  /// ✅ Monitor silence and auto-restart after 5 seconds
  void _startListeningMonitor() {
    _listeningMonitor?.cancel();
    _listeningMonitor = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_autoRestartAllowed || _onResultCallback == null) return;

      final now = DateTime.now();
      final silenceDuration = now.difference(_lastHeardTime ?? now).inSeconds;

      if (silenceDuration > 5) {
        if (!_speech.isListening) {
          debugPrint('Auto-restarting after prolonged silence...');
          onSilenceDetected?.call();
          await startListening(
            _onResultCallback!,
            autoRestart: _autoRestartAllowed,
          );
        } else {
          debugPrint('Still listening, skipping auto-restart.');
        }
      }
    });
  }

  /// ✅ Stops recognition cleanly
  Future<void> stopListening() async {
    _autoRestartAllowed = false;

    _listeningMonitor?.cancel();
    _listeningMonitor = null;

    if (_speech.isListening) {
      debugPrint('🛑 Stopped listening.');
      await _speech.stop();
    }

    _onResultCallback = null;
    _lastHeardTime = null;
  }

  bool get isListening => _speech.isListening;

  /// ✅ Maps spoken phrases to specific app actions
  String processCommand(String command) {
    const Map<String, List<String>> featureKeywords = {
      'read_notes': ['read notes', 'read', 'notes'],
      'ask_questions': ['ask question', 'ask', 'question', 'questions'],
      'start_quiz': ['start quiz', 'quiz', 'begin quiz'],
      'progress': ['progress', 'show progress', 'view progress'],
      'upload_notes': ['upload files', 'upload file', 'add file'],
    };

    for (final entry in featureKeywords.entries) {
      if (entry.value.any((keyword) => command.contains(keyword))) {
        debugPrint('Matched command: ${entry.key}');
        return entry.key;
      }
    }

    debugPrint('No match found for: $command');
    return '';
  }
}
