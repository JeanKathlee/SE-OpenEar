import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_recognition_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart'; // For routeObserver

class VoiceCommandButton extends StatefulWidget {
  final Function(String) onCommandRecognized;
  final Future<void> Function(String) speak;

  const VoiceCommandButton({
    Key? key,
    required this.onCommandRecognized,
    required this.speak,
  }) : super(key: key);

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton>
    with RouteAware {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  bool _isListening = false;
  bool _isMuted = false;

  String? _lastCommand;
  DateTime _lastCommandTime = DateTime.now();
  final Duration _debounceDuration = const Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _setupVoiceService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopListening(resetState: true);
    super.dispose();
  }

  @override
  void didPushNext() {
    _stopListening(resetState: true);
  }

  @override
  void didPopNext() {
    setState(() {
      _isListening = false;
      _isMuted = false;
      _lastCommand = null;
    });
  }

  Future<void> _setupVoiceService() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    // ✅ Attach auto-silence callback for “I’m still here”
    _voiceService.onSilenceDetected = () async {
      if (!_isMuted) {
        await widget.speak("I'm still here. You can speak again.");
      }
    };

    await _voiceService.initialize();
  }

  Future<void> _startListening() async {
    if (_isMuted) return;

    if (!_voiceService.isListening) {
      await _voiceService.startListening((recognizedWords) {
        if (_isMuted) return;

        final command = _voiceService.processCommand(recognizedWords);
        if (command.isEmpty) return;

        final now = DateTime.now();

        if (_lastCommand == command &&
            now.difference(_lastCommandTime) < _debounceDuration) {
          return;
        }

        _lastCommand = command;
        _lastCommandTime = now;
        widget.onCommandRecognized(command);
      }, autoRestart: true);
    }
  }

  Future<void> _stopListening({bool resetState = false}) async {
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
    }
    if (resetState) {
      _lastCommand = null;
      _lastCommandTime = DateTime.now();
      setState(() {
        _isListening = false;
        _isMuted = false;
      });
    }
  }

  void _toggleListening() {
    HapticFeedback.selectionClick();

    if (!_isListening) {
      setState(() {
        _isListening = true;
        _isMuted = false;
      });
      widget.speak('Active Listening');
      _startListening();
    } else {
      setState(() => _isMuted = !_isMuted);
      widget.speak(_isMuted ? 'Muted' : 'Unmuted');

      if (!_isMuted) {
        _startListening();
      } else {
        _voiceService.stopListening();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    IconData iconData;

    if (_isListening) {
      if (_isMuted) {
        bgColor = Colors.red;
        iconData = Icons.mic_off;
      } else {
        bgColor = Colors.green;
        iconData = Icons.mic;
      }
    } else {
      bgColor = Theme.of(context).primaryColor;
      iconData = Icons.mic_none;
    }

    return FloatingActionButton(
      onPressed: _toggleListening,
      backgroundColor: bgColor,
      child: Icon(iconData, color: Colors.white),
    );
  }
}
