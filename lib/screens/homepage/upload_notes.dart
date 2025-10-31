import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';


class UploadNotes extends StatefulWidget {
  const UploadNotes({super.key});

  @override
  State<UploadNotes> createState() => _UploadNotesState();
}

class _UploadNotesState extends State<UploadNotes> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _spokenInputController = TextEditingController();

  bool _listening = false;
  String _lastWords = '';
  String _lastSpokenText = '';
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _announceScreen();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
  }

  Future<void> _announceScreen() async {
    await _tts.stop();
    await _tts.speak('You are now in the Upload Notes screen.');
  }

  // MANUAL FILE PICKER
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx', 'pdf'],
      );

      if (result == null || result.files.isEmpty) {
        await _tts.speak("No file selected.");
        return;
      }

      final picked = result.files.single;
      if (picked.path == null) {
        await _tts.speak("File path unavailable.");
        return;
      }

      final file = File(picked.path!);
      await _tts.speak("Opening file ${picked.name}");
      await _handlePickedFile(file);
    } catch (e) {
      debugPrint('Manual file pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('File pick error: $e')));
      }
      await _tts.speak("Sorry, there was an error picking the file.");
    }
  } 

  Future<void> _handlePickedFile(File file) async {
  try {
    if (!await file.exists()) {
      await _tts.speak("File not found.");
      debugPrint("File does not exist: ${file.path}");
      return;
    }

    final extension = file.path.split('.').last.toLowerCase();
    String? extractedText;

    // --- Handle PDF files ---
    if (extension == 'pdf') {
      await _tts.speak("Reading your PDF file, please wait.");
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      extractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      // Clean and normalize spaces
      extractedText = extractedText
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // remove hidden control chars
      .replaceAll(RegExp(r'(?<=[a-zA-Z])\s(?=[a-zA-Z])'), '') // remove spaces between letters
      .replaceAll(RegExp(r'\s+'), ' ') // normalize multiple spaces
      .replaceAll(RegExp(r'\s([.,!?])'), r'\1') // remove space before punctuation
      .trim();

      if (extractedText.isEmpty) {
        await _tts.speak("Sorry, I could not extract any readable text from your PDF.");
        return;
      }

      debugPrint("PDF content extracted: $extractedText");
      await _speakText(extractedText);
    }

    // --- Handle DOCX files ---
    else if (extension == 'docx') {
      await _tts.speak("Reading your Word document, please wait.");
      extractedText = await _extractTextFromDocx(file);

      if (extractedText == null || extractedText.isEmpty) {
        await _tts.speak("Sorry, I could not extract any readable text from your document.");
        return;
      }

      extractedText = extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      debugPrint("DOCX content extracted: $extractedText");
      await _speakText(extractedText);
    }

    // --- Handle TXT files ---
    else if (extension == 'txt') {
      await _tts.speak("Reading your text file.");
      extractedText = await file.readAsString();

      if (extractedText.isEmpty) {
        await _tts.speak("The text file is empty.");
        return;
      }

      extractedText = extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      debugPrint("Text file content extracted: $extractedText");
      await _speakText(extractedText);
    }

    // --- Unsupported types ---
    else {
      await _tts.speak("Unsupported file type. Please select a PDF, Word, or text file.");
      debugPrint("Unsupported file type: $extension");
    }
  } catch (e) {
    debugPrint("Error handling picked file: $e");
    await _tts.speak("There was an error opening your file.");
  }
}


  // VOICE SEARCH FILE PICKER (Recursive version)
Future<void> _pickFileWithDirs(String spoken) async {
  try {
    // Ask for storage permission
    final storageStatus = await Permission.storage.request();
    final manageStatus = await Permission.manageExternalStorage.request();

    if (!storageStatus.isGranted && !manageStatus.isGranted) {
      await _tts.speak("Storage permission is required to search files.");
      return;
    }

    spoken = spoken.toLowerCase().trim();
    if (spoken.isEmpty) {
      await _tts.speak("No spoken input detected.");
      return;
    }

    await _tts.speak("Searching your downloads and documents for $spoken.");

    // Directories to search
    final dirs = [
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Documents'),
    ];

    List<FileSystemEntity> foundFiles = [];

    // Recursive search
    Future<void> searchDirectory(Directory dir) async {
      if (!await dir.exists()) return;
      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final filename = entity.path.split('/').last.toLowerCase();
            if (filename.contains(spoken)) {
              foundFiles.add(entity);
            }
          }
        }
      } catch (e) {
        debugPrint("Skipping ${dir.path}: $e");
      }
    }

    // Search all directories
    for (final dir in dirs) {
      await searchDirectory(dir);
    }

    if (foundFiles.isEmpty) {
      await _tts.speak("No matching file found in your downloads or documents.");
      return;
    }

    final firstMatch = foundFiles.first;
    final fileName = firstMatch.path.split('/').last;
    await _tts.speak(
      "Found ${foundFiles.length} matching file${foundFiles.length > 1 ? 's' : ''}. Opening $fileName."
    );

    debugPrint("Found files: ${foundFiles.map((f) => f.path).toList()}");

    // Open the first matching file
    await _handlePickedFile(File(firstMatch.path));

  } catch (e) {
    debugPrint('⚠️ Voice search error: $e');
    await _tts.speak("Sorry, I could not open that file.");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File search error: $e')),
      );
    }
  }
}

//  Extract text from DOCX
Future<String?> _extractTextFromDocx(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final xmlFile = archive.firstWhere(
      (f) => f.name.toLowerCase().contains('word/document.xml'),
      orElse: () => throw Exception('document.xml not found'),
    );

    final xmlContent = utf8.decode(xmlFile.content as List<int>);

    // Remove XML tags and clean spacing
    final text = xmlContent
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  } catch (e) {
    debugPrint(' DOCX extract error: $e');
    return 'Could not extract DOCX text: $e';
  }
}


  Future<void> _speakText(String text) async {
    _lastSpokenText = text;
    await _tts.stop();
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
    if (mounted) setState(() => _isPaused = false);
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      await _tts.speak("Microphone permission is required to use voice navigation.");
      return false;
    }
    return true;
  }

  // START VOICE FLOW
  Future<void> _startVoiceFlow() async {
    final micGranted = await _requestMicPermission();
    if (!micGranted) {
      await _tts.speak('Microphone permission is required.');
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (errorNotification) =>
          debugPrint('Speech error: ${errorNotification.errorMsg}'),
    );

    if (!available) {
      await _tts.speak('Speech recognition not available');
      return;
    }

    _lastWords = '';
    setState(() => _listening = true);

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
          debugPrint('Heard final: $_lastWords');
        }
      },
      localeId: 'en_US',
      partialResults: true,
      onDevice: false,
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.black87,
          title:
              const Text('Voice Navigate', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Say part of the file name, then press Stop.',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              _lastWords.isEmpty
                  ? const Icon(Icons.mic, size: 48, color: Colors.greenAccent)
                  : Text('Heard: \"$_lastWords\"',
                      style: const TextStyle(color: Colors.yellowAccent)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _speech.stop();
                setState(() {
                  _listening = false;
                });
                Navigator.of(context).pop();
                if (_lastWords.trim().isEmpty) {
                  await _tts.speak("No spoken input detected.");
                } else {
                  await _pickFileWithDirs(_lastWords);
                }
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
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.cancel();
    _speech.stop();
    _spokenInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            const Text('Upload Notes', style: 
            TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurpleAccent,
        iconTheme: const IconThemeData(color: Colors.white),
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
                  color: Colors.black87,
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
                  onPressed: () => _pickFile(),
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
                        await _tts.speak(_lastSpokenText);
                        setState(() => _isPaused = false);
                      } else {
                        await _tts.pause();
                        setState(() => _isPaused = true);
                      }
                    },
                    icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        size: 24),
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
