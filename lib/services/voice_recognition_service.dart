import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecognitionService {
  static final VoiceRecognitionService _instance =
      VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _autoRestartAllowed = false;

  Function(String)? _onResultCallback;
  VoidCallback? onSilenceDetected; // 👈 Optional callback for “I’m still here”

  Timer? _listeningMonitor;
  DateTime? _lastHeardTime;

  /// Auto-initialize if not yet initialized
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('Speech recognition error: $error'),
      onStatus: (status) async {
        debugPrint('Speech recognition status: $status');

        // If speech ended or went idle
        if (_autoRestartAllowed &&
            (status == 'notListening' || status == 'done') &&
            _onResultCallback != null) {
          await Future.delayed(const Duration(milliseconds: 2500));
          if (!_autoRestartAllowed) return;
          if (_speech.isListening) {
            debugPrint('Skipped restart: already listening');
            return;
          }

          debugPrint('Restarting after short silence...');
          await startListening(_onResultCallback!, autoRestart: true);
        }
      },
    );

    debugPrint(
      _isInitialized
          ? 'Speech recognition initialized successfully'
          : 'Speech recognition failed to initialize',
    );

    return _isInitialized;
  }

  Future<void> startListening(
    Function(String) onResult, {
    bool autoRestart = false,
  }) async {
    _onResultCallback = onResult;
    _autoRestartAllowed = autoRestart;

    // Self-initialize if not already done
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        debugPrint('Speech recognition failed to initialize');
        return;
      }
    }

    // Skip if already listening
    if (_speech.isListening) {
      debugPrint('Skipped restart: already listening');
      return;
    }

    debugPrint('Starting to listen...');
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

  /// Tracks silence and restarts after prolonged silence (15s)
  void _startListeningMonitor() {
    _listeningMonitor?.cancel();
    _listeningMonitor = Timer.periodic(const Duration(seconds: 1), (
      Timer timer,
    ) async {
      if (!_autoRestartAllowed) return;
      if (_onResultCallback == null) return;

      final now = DateTime.now();
      final silenceDuration = now.difference(_lastHeardTime ?? now).inSeconds;

      if (silenceDuration > 12) {
        if (!_speech.isListening) {
          debugPrint('Auto-restarting after prolonged silence...');
          onSilenceDetected?.call(); // 👈 trigger the “I’m still here” message
          await startListening(
            _onResultCallback!,
            autoRestart: _autoRestartAllowed,
          );
        } else {
          debugPrint('Still listening; skipping auto-restart.');
        }
      }
    });
  }

  Future<void> stopListening() async {
    _autoRestartAllowed = false;
    _listeningMonitor?.cancel();
    _listeningMonitor = null;
    debugPrint('Stopped listening');
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  String processCommand(String command) {
    const Map<String, List<String>> featureKeywords = {
      'read_notes': ['read notes', 'read', 'notes'],
      'ask_questions': ['ask questions', 'ask', 'question', 'questions'],
      'start_quiz': ['start quiz', 'start', 'quiz'],
      'progress': ['progress', 'show progress', 'view progress'],
      'upload_notes': ['upload notes', 'upload', 'add notes'],
    };

    for (final entry in featureKeywords.entries) {
      if (entry.value.any((keyword) => command.contains(keyword))) {
        debugPrint('Matched command: ${entry.key}');
        return entry.key;
      }
    }

    debugPrint('No command matched for: $command');
    return '';
  }
}
