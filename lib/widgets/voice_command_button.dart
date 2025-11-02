import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_recognition_service.dart';
import '../main.dart'; // for routeObserver

class VoiceCommandButton extends StatefulWidget {
  final Function(String) onCommandRecognized;
  final Future<void> Function(String) speak;

  const VoiceCommandButton({
    super.key,
    required this.onCommandRecognized,
    required this.speak,
  });

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton>
    with RouteAware {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  bool _isListening = false;
  bool _isMuted = false;
  bool _isNavigating = false;

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

  /// Called when pushing a new screen (navigating away)
  @override
  void didPushNext() {
    _stopListening(resetState: true);
  }

  /// Called when returning to this screen
  @override
  void didPopNext() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isNavigating = false;
        _isMuted = false;
        _lastCommand = null;
        _isListening = false;
      });
      _voiceService.stopListening();
    });
  }

  /// ✅ Request microphone permission + setup service
  Future<void> _setupVoiceService() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    _voiceService.onSilenceDetected = () async {
      if (!_isMuted && mounted) {
        await widget.speak("I'm still here. You can speak again.");
      }
    };

    await _voiceService.initialize();
  }

  /// ✅ Start voice listening and handle recognized commands
  Future<void> _startListening() async {
    if (_isMuted || _voiceService.isListening || _isNavigating) return;

    await _voiceService.startListening((recognizedWords) async {
      if (_isMuted || _isNavigating) return;

      final command = _voiceService.processCommand(recognizedWords);
      if (command.isEmpty) return;

      final now = DateTime.now();
      if (_lastCommand == command &&
          now.difference(_lastCommandTime) < _debounceDuration) {
        return; // prevent double trigger
      }

      _isNavigating = true;
      _lastCommand = command;
      _lastCommandTime = now;

      // Stop listening before navigation to prevent echo commands
      await _voiceService.stopListening();

      // Run the recognized command
      await widget.onCommandRecognized(command);

      // Allow reactivation after navigation settles
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _isNavigating = false;
      });
    }, autoRestart: true);

    if (mounted) {
      setState(() => _isListening = true);
    }
  }

  /// ✅ Stop voice listening safely
  Future<void> _stopListening({bool resetState = false}) async {
    await _voiceService.stopListening();
    if (!mounted) return;

    if (resetState) {
      _lastCommand = null;
      _lastCommandTime = DateTime.now();
      _isNavigating = false;
      setState(() {
        _isListening = false;
        _isMuted = false;
      });
    } else {
      setState(() => _isListening = _voiceService.isListening);
    }
  }

  /// ✅ Toggle voice listening on/off
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

      if (_isMuted) {
        _voiceService.stopListening();
      } else {
        _startListening();
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
