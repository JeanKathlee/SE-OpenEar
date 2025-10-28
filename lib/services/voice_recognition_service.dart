import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecognitionService {
  static final VoiceRecognitionService _instance =
      VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  Function(String)? _onResultCallback;
  bool _autoRestartAllowed = false;

  Future<bool> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');

          // Only auto-restart if explicitly allowed
          if (_autoRestartAllowed &&
              (status == 'notListening' || status == 'done') &&
              _onResultCallback != null) {
            startListening(_onResultCallback!);
          }
        },
      );
      debugPrint(
        _isInitialized
            ? 'Speech recognition initialized successfully'
            : 'Speech recognition failed to initialize',
      );
    }
    return _isInitialized;
  }

  Future<void> startListening(
    Function(String) onResult, {
    bool autoRestart = false,
  }) async {
    _onResultCallback = onResult;
    _autoRestartAllowed = autoRestart;

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    if (!_speech.isListening) {
      debugPrint('Starting to listen...');
      await _speech.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords.toLowerCase();
          if (recognizedWords.isNotEmpty) {
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
    }
  }

  Future<void> stopListening() async {
    _autoRestartAllowed = false;
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
