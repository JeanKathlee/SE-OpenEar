import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

class UploadNotes extends StatefulWidget {
  const UploadNotes({super.key});

  @override
  State<UploadNotes> createState() => _UploadNotesState();
}

class _UploadNotesState extends State<UploadNotes> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  String _lastWords = '';

  Timer? _silenceTimer; // <-- moved here as class member

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showUploadPrompt());
  }

  Future<void> _showUploadPrompt() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upload Notes'),
        content: const Text(
          'Upload manually with the + button or use voice to navigate to local files.',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickFile();
            },
            child: const Text('Upload Manually'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startVoiceFlow();
            },
            child: const Text('Use Voice'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile({String? hintName}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No file selected')));
        }
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to access file path')),
          );
        }
        return;
      }

      final file = File(path);
      await _handlePickedFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File pick error: $e')));
      }
    }
  }

  Future<void> _handlePickedFile(File file) async {
    final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
    String? extracted;

    try {
      if (name.endsWith('.txt')) {
        extracted = await file.readAsString();
      } else if (name.endsWith('.docx')) {
        extracted = await _extractTextFromDocx(file);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported file type: $name')),
          );
        }
        return;
      }

      if (extracted == null || extracted.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No readable text found in file')),
          );
        }
        return;
      }

      await _speakText(extracted);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Playing text from: $name')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing file: $e')));
      }
    }
  }

  Future<String?> _extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive) {
        if (f.name == 'word/document.xml') {
          final data = f.content as List<int>;
          final xml = utf8.decode(data);
          final plain = xml.replaceAll(RegExp(r'<[^>]+>'), ' ');
          return plain.replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }
      return null;
    } catch (e) {
      return 'Could not extract DOCX text: $e';
    }
  }

  Future<void> _speakText(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _startVoiceFlow() async {
    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      return;
    }

    setState(() => _listening = true);
    _lastWords = '';
    DateTime lastHeardTime = DateTime.now();

    // Start a timer to check prolonged silence
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now();
      final silenceDuration = now.difference(lastHeardTime).inSeconds;
      if (silenceDuration > 5) {
        await _tts.speak("I'm still here. You can speak again.");
        lastHeardTime = DateTime.now(); // reset after feedback
      }
    });

    _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });
        if (_lastWords.isNotEmpty) {
          lastHeardTime = DateTime.now(); // reset timer whenever user speaks
        }
      },
      localeId: 'en_US',
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Voice Navigate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Say part of the file name you want, then press Stop.',
                style: TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 12),
              _lastWords.isEmpty
                  ? Center(
                      child: Icon(Icons.mic, size: 48, color: Colors.green),
                    )
                  : Text('Heard: "$_lastWords"'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _speech.stop();
                _silenceTimer?.cancel();
                setState(() => _listening = false);
                Navigator.of(context).pop();
                _pickFile(hintName: _lastWords);
              },
              child: const Text('Stop'),
            ),
            TextButton(
              onPressed: () async {
                await _speech.stop();
                _silenceTimer?.cancel();
                setState(() => _listening = false);
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop(); // ensure temporary listener is fully stopped
    _silenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Notes')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Upload notes manually or use voice to navigate to local files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Manually'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _startVoiceFlow,
              icon: const Icon(Icons.mic),
              label: const Text('Use Voice to Navigate'),
            ),
          ],
        ),
      ),
    );
  }
}
