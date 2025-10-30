import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  String _lastSpokenText = ''; // store current TTS text
  bool _isPaused = false; // tracks Pause/Resume state

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.stop();
    await _tts.speak('You are now in the Upload Notes screen.');
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final file = File(path);
      await _handlePickedFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File pick error: $e')),
        );
      }
    }
  }

  Future<void> _handlePickedFile(File file) async {
    final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
    String? text;

    try {
      if (name.endsWith('.txt')) {
        text = await file.readAsString();
      } else if (name.endsWith('.docx')) {
        text = await _extractTextFromDocx(file);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported file type: $name')),
          );
        }
        return;
      }

      if (text == null || text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No readable text found')),
          );
        }
        return;
      }

      await _speakText(text);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Playing text from: $name')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<String?> _extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive) {
        if (f.name == 'word/document.xml') {
          final xml = utf8.decode(f.content as List<int>);
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
    _lastSpokenText = text; // save for resume
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
    setState(() => _isPaused = false);
  }

  Future<void> _startVoiceFlow() async {
    final available = await _speech.initialize();
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

    _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });
      },
      localeId: 'en_US',
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Voice Navigate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Say part of the file name, then press Stop to pick a file.'),
            const SizedBox(height: 12),
            _lastWords.isEmpty
                ? const Icon(Icons.mic, size: 48, color: Colors.green)
                : Text('Heard: "$_lastWords"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _speech.stop();
              setState(() => _listening = false);
              Navigator.of(context).pop();
              await _pickFile();
            },
            child: const Text('Stop'),
          ),
          TextButton(
            onPressed: () async {
              await _speech.stop();
              setState(() => _listening = false);
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), 
      appBar: AppBar(
        title: const Text('Upload Notes'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Upload notes manually or use voice to navigate to local files.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, size: 28),
                  label: const Text('Upload Manually'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent[700],
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _startVoiceFlow,
                  icon: const Icon(Icons.mic, size: 28),
                  label: const Text('Use Voice to Navigate'),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(120, 50),
                    ),
                    onPressed: () async {
                      await _tts.stop();
                      setState(() => _isPaused = false);
                    },
                    icon: const Icon(Icons.stop, size: 24),
                    label: const Text('Stop'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(120, 50),
                    ),
                    onPressed: () async {
                      if (_isPaused) {
                        await _tts.speak(_lastSpokenText); // Resume
                        setState(() => _isPaused = false);
                      } else {
                        await _tts.pause(); // Pause
                        setState(() => _isPaused = true);
                      }
                    },
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 24),
                    label: Text(_isPaused ? 'Resume' : 'Pause'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
