import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../home_page.dart';
import 'read_notes.dart';
import 'start_quiz.dart';
import 'progress.dart';
import 'upload_notes.dart';
import '../../widgets/voice_command_button.dart';
import '../../services/voice_recognition_service.dart';

class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  final FlutterTts _tts = FlutterTts();
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  bool _isPlaying = false;
  List<String> _chunks = [];
  int _currentChunkIndex = 0;

  final String _script =
      '''Welcome to OpenEar — your learning companion designed for visually impaired learners. This app helps you listen to study materials, ask questions by voice, take quizzes, upload notes, and track your progress — all through your voice.

Here’s how to use OpenEar. To get started, simply say one of the following commands: Read my notes — to listen to your study materials. Start a quiz — to begin a quiz session. Check my progress — to hear your saved quiz scores. Ask a question — to inquire about your study materials using your voice. Upload file or Upload notes — to add new study materials for reading. You can say Help anytime to hear these instructions again.

If you want me to read your notes, say Read my notes. I’ll ask if you want to upload a text file or type your notes manually. After loading your file, I’ll read the content aloud. You can say Pause, Resume, or Stop reading anytime to control playback.

To upload new study materials, say Upload file or Upload notes. You can select a text file from your device or type your notes directly. Once uploaded, I’ll store them safely and make them available for listening whenever you need.

If you want to ask a question, say Ask a question. I’ll listen to your voice and respond based on your study materials. Speak clearly, and you can say Repeat answer if you want me to say it again.

When you say Start a quiz, I’ll begin asking you questions aloud. Answer by speaking clearly — for example, say A, B, True, or False. I’ll tell you if your answer is correct, and I’ll keep track of your score. At the end, I’ll read your final score and save it automatically.

To hear your past quiz scores, say Check my progress. I’ll read your previous scores, dates, and performance summaries from the saved file.

You can also say: Repeat question — if you didn’t hear the last one, Go back — to return to the main menu, or Exit app — to close OpenEar. Remember, you don’t need to look at the screen at all — I’ll guide you through everything.

That’s it! You’re now ready to start learning with OpenEar. Would you like to read your notes, ask a question, or start a quiz?''';

  @override
  void initState() {
    super.initState();
    _setupTts();
    _setupVoiceService();
    // Auto-start the tutorial on enter
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakScript());
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.48);
    // When a chunk finishes, advance to the next one and continue playing
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      // Advance to next chunk only if we are in playing state
      if (_isPlaying) {
        _currentChunkIndex++;
        if (_currentChunkIndex < _chunks.length) {
          // Play next chunk
          _playCurrentChunk();
        } else {
          // Reached the end
          setState(() {
            _isPlaying = false;
            _currentChunkIndex = _chunks.length; // mark finished
          });
        }
      }
    });
  }

  void _prepareChunks() {
    // Normalize whitespace and split into sentence-like chunks for resumable playback
    final normalized = _script
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Split on sentence boundaries (., !, ?) followed by space
    final parts = normalized.split(RegExp(r'(?<=[.!?])\s+'));
    _chunks = parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (_chunks.isEmpty) {
      _chunks.add(normalized);
    }
  }

  Future<void> _setupVoiceService() async {
    await _voiceService.initialize();
    // Keep a light on-silence handler to give helpful prompts
    _voiceService.onSilenceDetected = () async {
      if (mounted && !_isPlaying) {
        await _tts.speak(
          "I'm still here. Say 'Read my notes', 'Start a quiz', or 'Skip' to continue.",
        );
      }
    };

    // Start passive listening so users can say commands while tutorial plays
    await _voiceService.startListening((recognizedWords) {
      final lower = recognizedWords.toLowerCase();

      // direct shortcuts first
      if (lower.contains('skip') ||
          lower.contains('go back') ||
          lower.contains('exit')) {
        _navigateToHome();
        return;
      }

      final command = _voiceService.processCommand(recognizedWords);
      if (command.isEmpty) return;

      if (command == 'read_notes') {
        _openReadNotes();
      } else if (command == 'start_quiz') {
        _openStartQuiz();
      } else if (command == 'progress') {
        _openProgress();
      } else if (command == 'upload_notes') {
        _openUploadNotes();
      } else if (command == 'ask_questions') {
        _openReadNotes();
      }
    }, autoRestart: true);
  }

  Future<void> _speakScript() async {
    if (_isPlaying) return;

    // Prepare chunks lazily
    if (_chunks.isEmpty) {
      _prepareChunks();
    }

    // If we've finished previously, restart from beginning
    if (_currentChunkIndex >= _chunks.length) {
      _currentChunkIndex = 0;
    }

    setState(() => _isPlaying = true);
    // Ensure any previous speech is stopped and start playing current chunk
    await _tts.stop();
    _playCurrentChunk();
  }

  Future<void> _playCurrentChunk() async {
    if (!mounted) return;
    if (_currentChunkIndex < 0) _currentChunkIndex = 0;
    if (_currentChunkIndex >= _chunks.length) {
      setState(() => _isPlaying = false);
      return;
    }

    final text = _chunks[_currentChunkIndex];
    try {
      await _tts.speak(text);
    } catch (e) {
      // In case of a TTS error, stop playback and surface state
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    // Do not reset _currentChunkIndex so playback can resume from here
    setState(() => _isPlaying = false);
  }

  void _navigateToHome() {
    if (!mounted) return;
    _stopSpeaking();
    _voiceService.stopListening();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _openReadNotes() async {
    await _stopSpeaking();
    await _voiceService.stopListening();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReadNotesScreen()),
    );
    // resume tutorial listening if user returns
    await _voiceService.startListening((words) {}, autoRestart: true);
  }

  void _openStartQuiz() async {
    await _stopSpeaking();
    await _voiceService.stopListening();
    if (!mounted) return;
    await StartQuiz.show(context);
    await _voiceService.startListening((words) {}, autoRestart: true);
  }

  void _openProgress() async {
    await _stopSpeaking();
    await _voiceService.stopListening();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Progress()),
    );
    await _voiceService.startListening((words) {}, autoRestart: true);
  }

  void _openUploadNotes() async {
    await _stopSpeaking();
    await _voiceService.stopListening();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadNotes()),
    );
    await _voiceService.startListening((words) {}, autoRestart: true);
  }

  @override
  void dispose() {
    _tts.stop();
    _voiceService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructions'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _script,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Large, high-contrast controls for visually impaired users
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    label: _isPlaying ? 'flutorial' : 'Play tutorial',
                    child: ElevatedButton.icon(
                      onPressed: _isPlaying ? _stopSpeaking : _speakScript,
                      icon: Icon(
                        _isPlaying ? Icons.stop : Icons.play_arrow,
                        size: 28,
                      ),
                      label: Text(
                        _isPlaying ? 'Stop Tutorial' : 'Play Tutorial',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 72),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Skip tutorial and go to Home',
                    child: ElevatedButton(
                      onPressed: _navigateToHome,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 72),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
