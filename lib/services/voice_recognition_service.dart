import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecognitionService {
  static final VoiceRecognitionService _instance = VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
    }
    return _isInitialized;
  }

  Future<void> startListening(Function(String) onResult) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Failed to initialize speech recognition');
        return;
      }
    }

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final recognizedWords = result.recognizedWords.toLowerCase();
          onResult(recognizedWords);
        }
      },
      localeId: 'en_US',
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  String processCommand(String command) {
    // Define keywords for each feature
    const Map<String, List<String>> featureKeywords = {
      'read_notes': ['read', 'notes', 'read notes'],
      'ask_questions': ['ask', 'questions', 'ask questions'],
      'start_quiz': ['start', 'quiz', 'start quiz'],
      'progress': ['progress', 'show progress', 'view progress'],
      'upload_notes': ['upload', 'notes', 'upload notes', 'add notes'],
    };

    // Check which feature keywords match the command
    for (final entry in featureKeywords.entries) {
      if (entry.value.any((keyword) => command.contains(keyword))) {
        return entry.key;
      }
    }

    return ''; // Return empty string if no match found
  }
}