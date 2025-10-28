import 'package:flutter/material.dart';
import '../services/voice_recognition_service.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- Add this

class VoiceCommandButton extends StatefulWidget {
  final Function(String) onCommandRecognized;

  const VoiceCommandButton({Key? key, required this.onCommandRecognized})
    : super(key: key);

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton> {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  bool _isListening = false;

  void _toggleListening() async {
    if (!_isListening) {
      // Request mic permission first
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission denied');
        return;
      }

      final isInitialized = await _voiceService.initialize();
      if (isInitialized) {
        setState(() => _isListening = true);
        debugPrint('🎙️ Mic ON');
        await _voiceService.startListening((recognizedWords) {
          debugPrint('🎯 Raw recognized: $recognizedWords');
          final command = _voiceService.processCommand(recognizedWords);
          debugPrint('📢 Processed command: $command');
          if (command.isNotEmpty) {
            widget.onCommandRecognized(command);
          }
          setState(() => _isListening = false);
        });
      }
    } else {
      debugPrint('🔇 Mic OFF');
      setState(() => _isListening = false);
      await _voiceService.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _toggleListening,
      backgroundColor: _isListening
          ? Colors.red
          : Theme.of(context).primaryColor,
      child: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: Colors.white,
      ),
    );
  }
}
