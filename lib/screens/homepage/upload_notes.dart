// upload_notes.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/quiz_validator.dart';
import 'dart:async';

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
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _announceEntry();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.55);
    await _tts.awaitSpeakCompletion(false);
  }

  Future<void> _announceEntry() async {
    try {
      await _tts.stop();
      await _tts.speak('You are now in the Upload Notes screen.');
    } catch (_) {}
  }

  Future<void> _announceExit() async {
    try {
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _tts.speak('Upload Notes screen closed.');
    } catch (_) {}
  }

  Future<bool> _onWillPop() async {
    if (_isClosing) return false;
    _isClosing = true;
    try {
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _tts.speak('Upload Notes screen closed.');
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
    return false;
  }

  // ---------------------------
  // MANUAL FILE PICKER (web + mobile)
  // ---------------------------
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx', 'pdf'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        await _tts.speak("No file selected.");
        return;
      }

      final picked = result.files.single;
      await _tts.speak("Opening file ${picked.name}");

      if (kIsWeb) {
        if (picked.bytes == null) {
          await _tts.speak("File data unavailable.");
          return;
        }
        await _processFileBytes(picked.name, picked.bytes!);
      } else {
        if (picked.path == null) {
          await _tts.speak("File path unavailable.");
          return;
        }
        await _processFilePath(picked.path!);
      }
    } catch (e) {
      debugPrint('Manual file pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File pick error: $e')),
        );
      }
      await _tts.speak("Sorry, there was an error picking the file.");
    }
  }

  // Unified processors ----------------------------------------------------
  Future<void> _processFileBytes(String fileName, List<int> bytes) async {
    final extension = fileName.split('.').last.toLowerCase();
    final title = _friendlyTitleFromName(fileName);
    String? extractedText;

    if (extension == 'pdf') {
      await _tts.speak("Processing your PDF file, please wait.");
      extractedText = _extractTextFromPdfBytes(bytes);
    } else if (extension == 'docx') {
      await _tts.speak("Processing your Word document, please wait.");
      extractedText = await _extractTextFromDocxBytes(bytes);
    } else if (extension == 'txt') {
      await _tts.speak("Processing your text file.");
      extractedText = utf8.decode(bytes);
    } else {
      await _tts.speak("Unsupported file type. Please select a PDF, Word, or text file.");
      return;
    }

    if (extractedText == null || extractedText.trim().isEmpty) {
      await _tts.speak("Sorry, I could not extract any readable text from your file.");
      return;
    }

    extractedText = _cleanExtractedText(extractedText);
    debugPrint("Extracted content (preview): ${extractedText.substring(0, extractedText.length > 200 ? 200 : extractedText.length)}");

    await _saveNote(title, extractedText);
    await _tts.speak("Upload successful. Go to Read Notes to listen to the file.");
  }

  Future<void> _processFilePath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await _tts.speak("File not found.");
      return;
    }

    final extension = path.split('.').last.toLowerCase();
    final title = _friendlyTitleFromName(path.split(Platform.pathSeparator).last);
    String? extractedText;

    if (extension == 'pdf') {
      await _tts.speak("Processing your PDF file, please wait.");
      final bytes = await file.readAsBytes();
      extractedText = _extractTextFromPdfBytes(bytes);
    } else if (extension == 'docx') {
      await _tts.speak("Processing your Word document, please wait.");
      extractedText = await _extractTextFromDocx(file);
    } else if (extension == 'txt') {
      await _tts.speak("Processing your text file.");
      extractedText = await file.readAsString();
    } else {
      await _tts.speak("Unsupported file type. Please select a PDF, Word, or text file.");
      return;
    }

    if (extractedText == null || extractedText.trim().isEmpty) {
      await _tts.speak("Sorry, I could not extract any readable text from your file.");
      return;
    }

    extractedText = _cleanExtractedText(extractedText);
    debugPrint("Extracted content (preview): ${extractedText.substring(0, extractedText.length > 200 ? 200 : extractedText.length)}");

    await _saveNote(title, extractedText);
    await _tts.speak("Upload successful. Go to Read Notes to listen to the file.");
  }

  // ---------------------------
  // PDF / DOCX extraction helpers
  // ---------------------------
  String _extractTextFromPdfBytes(List<int> bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extracted = PdfTextExtractor(document).extractText();
      document.dispose();
      return extracted ?? '';
    } catch (e) {
      debugPrint("PDF extract error: $e");
      return '';
    }
  }

  Future<String?> _extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await _extractTextFromDocxBytes(bytes);
    } catch (e) {
      debugPrint('DOCX extract error (file): $e');
      return 'Could not extract DOCX text: $e';
    }
  }

  Future<String?> _extractTextFromDocxBytes(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final xmlFile = archive.firstWhere(
        (f) => f.name.toLowerCase().contains('word/document.xml'),
        orElse: () => throw Exception('document.xml not found'),
      );

      final xmlContent = utf8.decode(xmlFile.content as List<int>);

      // improved extraction: grab text nodes rather than bluntly removing tags
      final reg = RegExp(r'>([^<>]+)<');
      final matches = reg.allMatches(xmlContent);
      final buffer = StringBuffer();
      for (final m in matches) {
        final txt = m.group(1)?.trim();
        if (txt != null && txt.isNotEmpty) {
          buffer.write(txt);
          buffer.write(' ');
        }
      }
      final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      return text;
    } catch (e) {
      debugPrint('DOCX extract error: $e');
      return 'Could not extract DOCX text: $e';
    }
  }

  String _cleanExtractedText(String text) {
    return text
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s([.,!?;:])'), r'\1')
        .trim();
  }

  String _friendlyTitleFromName(String filename) {
    return filename.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ').replaceAll('-', ' ').trim();
  }

  // ---------------------------
  // SAVE NOTE + INDEXING
  // ---------------------------
  Future<void> _saveNote(String title, String content) async {
    if (kIsWeb) {
      // Web: use SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        const notesKey = 'openear_saved_notes';

        final notesJson = prefs.getString(notesKey);
        List<Map<String, dynamic>> notes = [];
        if (notesJson != null && notesJson.isNotEmpty) {
          final decoded = jsonDecode(notesJson);
          if (decoded is List) notes = decoded.cast<Map<String, dynamic>>();
        }

        // duplicates by title (case-insensitive) or exact content
        for (final note in notes) {
          final existingTitle = (note['title'] ?? '').toString();
          final existingContent = (note['content'] ?? '').toString();
          if (existingTitle.toLowerCase() == title.toLowerCase() || existingContent == content) {
            await _tts.speak('This note already exists. It will not be added again.');
            debugPrint('Duplicate note detected on web, skipping save: $title');
            return;
          }
        }

        final isQuizzable = QuizValidator.isQuizzable(content, title);
        final quizzabilityScore = QuizValidator.getQuizzabilityScore(content, title);
        final validationMessage = QuizValidator.getValidationMessage(content, title);

        final newNote = {
          'title': title,
          'content': content,
          'created': DateTime.now().toIso8601String(),
          'isQuizzable': isQuizzable,
          'quizzabilityScore': quizzabilityScore,
        };

        notes.add(newNote);
        await prefs.setString(notesKey, jsonEncode(notes));
        debugPrint('Note saved to web storage: $title (Quizzable: $isQuizzable)');
        await _tts.speak(validationMessage);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationMessage)));
        }
      } catch (e) {
        debugPrint('Error saving note to web storage: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
        }
      }
      return;
    }

    // Mobile: filesystem + index.json
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${appDir.path}${Platform.pathSeparator}saved_notes');
      if (!await notesDir.exists()) await notesDir.create(recursive: true);

      final indexFile = File('${notesDir.path}${Platform.pathSeparator}index.json');
      List<Map<String, dynamic>> index = [];
      if (await indexFile.exists()) {
        try {
          final contentStr = await indexFile.readAsString();
          final decoded = jsonDecode(contentStr);
          if (decoded is List) index = decoded.cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error reading index: $e');
          index = [];
        }
      }

      // duplicates
      for (final entry in index) {
        final existingTitle = (entry['title'] ?? '').toString();
        final existingContent = (entry['content'] ?? '').toString();
        if (existingTitle.toLowerCase() == title.toLowerCase() || existingContent == content) {
          await _tts.speak('This note already exists. It will not be added again.');
          debugPrint('Duplicate note detected, skipping save: $title');
          return;
        }
      }

      final safeTitle = title.isNotEmpty ? title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_') : 'note';
      final filename = '${DateTime.now().millisecondsSinceEpoch}_$safeTitle.json';
      final file = File('${notesDir.path}${Platform.pathSeparator}$filename');

      final map = {
        'title': title,
        'content': content,
        'created': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(map));

      // add to index (store filename and metadata)
      index.add({
        'title': title,
        'file': filename,
        'created': DateTime.now().toIso8601String(),
        'snippet': content.substring(0, content.length > 120 ? 120 : content.length),
      });

      await indexFile.writeAsString(jsonEncode(index));

      await _tts.speak('Saved note $title. You can read it from the Read Notes screen.');
      debugPrint('Saved note file: ${file.path}');
    } catch (e) {
      debugPrint('Error saving note: $e');
      await _tts.speak('There was an error saving the note.');
    }
  }

  // ---------------------------
  // Speech helpers + permission
  // ---------------------------
  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      await _tts.speak('Microphone permission is required to use voice navigation.');
      return false;
    }
    return true;
  }

  // ---------------------------
  // VOICE SEARCH
  // ---------------------------

  /// Convert filename to a spoken-friendly alias.
  /// Example: "IMG_0023-final_v2.docx" -> "image twenty three final version two"
  String _generateSpokenAlias(String filename) {
    // remove extension
    var base = filename.replaceAll(RegExp(r'\.\w+$'), '');
    // replace separators with spaces
    base = base.replaceAll(RegExp(r'[_\-]+'), ' ');
    // expand common tokens
    base = base.replaceAll(RegExp(r'\bfinal\b', caseSensitive: false), 'final');
    base = base.replaceAll(RegExp(r'\bvers?ion\b', caseSensitive: false), 'version');

    // replace digits sequences with words (simple conversion)
    base = base.replaceAllMapped(RegExp(r'\d+'), (m) {
      final numStr = m.group(0) ?? '';
      final numWord = _numberToWords(int.tryParse(numStr) ?? 0);
      return numWord;
    });

    // cleanup spacing
    base = base.replaceAll(RegExp(r'\s+'), ' ').trim();
    return base.toLowerCase();
  }

  // small number-to-words for common file numbers (0-9999)
  String _numberToWords(int n) {
    if (n == 0) return 'zero';
    final units = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'
    ];
    final tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

    String words = '';
    if (n >= 1000) {
      final thousands = n ~/ 1000;
      words += '${units[thousands]} thousand ';
      n = n % 1000;
    }
    if (n >= 100) {
      final hundreds = n ~/ 100;
      words += '${units[hundreds]} hundred ';
      n = n % 100;
    }
    if (n >= 20) {
      final t = n ~/ 10;
      words += '${tens[t]} ';
      final u = n % 10;
      if (u > 0) words += '${units[u]} ';
    } else if (n > 0) {
      words += '${units[n]} ';
    }
    return words.trim();
  }

  /// Levenshtein distance (for fuzzy matching)
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.filled(t.length + 1, 0);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i <= t.length; i++) v0[i] = i;
    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= t.length; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  double _similarity(String a, String b) {
    a = a.toLowerCase().trim();
    b = b.toLowerCase().trim();
    if (a.isEmpty || b.isEmpty) return 0.0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (dist / maxLen);
  }

  // Search user's downloads & documents and find best match
  Future<void> _pickFileWithDirs(String spoken) async {
    try {
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

      final dirs = [
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Documents'),
      ];

      List<_IndexedFile> indexed = [];

      Future<void> searchDirectory(Directory dir) async {
        if (!await dir.exists()) return;
        try {
          final entities = dir.listSync(recursive: true, followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              final rawName = entity.path.split('/').last;
              final lowerName = rawName.toLowerCase();
              final alias = _generateSpokenAlias(rawName);
              indexed.add(_IndexedFile(entity.path, rawName, alias));
            }
          }
        } catch (e) {
          debugPrint("Skipping ${dir.path}: $e");
        }
      }

      for (final dir in dirs) {
        await searchDirectory(dir);
      }

      if (indexed.isEmpty) {
        await _tts.speak("No files found in downloads or documents.");
        return;
      }

      // Compute best match across alias and filename
      double bestScore = 0.0;
      _IndexedFile? bestFile;
      for (final f in indexed) {
        // score alias vs spoken
        final aliasScore = _similarity(spoken, f.alias);
        final nameScore = _similarity(spoken, f.name.replaceAll(RegExp(r'\.\w+$'), '').replaceAll(RegExp(r'[_\-]+'), ' '));
        final combined = (aliasScore * 0.7) + (nameScore * 0.3);
        if (combined > bestScore) {
          bestScore = combined;
          bestFile = f;
        }
      }

      // also accept simple substring if similarity is low
      if (bestScore < 0.45) {
        final substringMatches = indexed.where((f) => f.name.toLowerCase().contains(spoken)).toList();
        if (substringMatches.isNotEmpty) {
          bestFile = substringMatches.first;
          bestScore = 0.5;
        }
      }

      if (bestFile == null || bestScore < 0.35) {
        await _tts.speak("No matching file found in your downloads or documents.");
        return;
      }

      // Confirm with user
      final fileName = bestFile.name;
      final aliasShown = bestFile.alias;
      await _tts.speak("Found file ${fileName}. Did you mean $aliasShown? Say yes to open or no to cancel.");

      final confirmed = await _listenForYesNo();
      if (!confirmed) {
        await _tts.speak("Okay, cancelled.");
        return;
      }

      await _tts.speak("Opening $fileName.");
      await _processFilePath(bestFile.path);
    } catch (e) {
      debugPrint('⚠️ Voice search error: $e');
      await _tts.speak("Sorry, I could not open that file.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File search error: $e')));
      }
    }
  }

  Future<bool> _listenForYesNo({int timeoutSeconds = 5}) async {
    try {
      final available = await _speech.initialize(
        onStatus: (s) => debugPrint('yesno status: $s'),
        onError: (e) => debugPrint('yesno error: ${e.errorMsg}'),
      );
      if (!available) return false;

      String heard = '';
      final completer = Completer<bool>();

      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            heard = result.recognizedWords.toLowerCase();
            if (heard.contains('yes') || heard.contains('yeah') || heard.contains('yup') || heard.contains('confirm') || heard.contains('open')) {
              if (!completer.isCompleted) completer.complete(true);
            } else if (heard.contains('no') || heard.contains('cancel') || heard.contains('stop')) {
              if (!completer.isCompleted) completer.complete(false);
            }
          }
        },
        listenFor: Duration(seconds: timeoutSeconds),
        localeId: 'en_US',
        partialResults: false,
        onDevice: false,
      );

      // fallback if nothing recognized
      Future.delayed(Duration(seconds: timeoutSeconds + 1), () {
        if (!completer.isCompleted) completer.complete(false);
      });

      final confirmed = await completer.future;
      await _speech.stop();
      return confirmed;
    } catch (e) {
      debugPrint('Error listening for yes/no: $e');
      try {
        await _speech.stop();
      } catch (_) {}
      return false;
    }
  }

  // -------------- Voice flow start (dialog kept similar but improved) ---------------
  Future<void> _startVoiceFlow() async {
  if (kIsWeb) {
    await _tts.speak('Voice navigation is only available on mobile. Please use manual upload.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice navigation is only available on mobile devices')),
      );
    }
    return;
  }

  final micGranted = await _requestMicPermission();
  if (!micGranted) return;

  final available = await _speech.initialize(
    onStatus: (status) => debugPrint('Speech status: $status'),
    onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
  );

  if (!available) {
    await _tts.speak('Speech recognition not available');
    return;
  }

  _lastWords = '';
  setState(() => _listening = true);

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Voice Navigate', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Say part of the file name after pressing "Start Listening", then press "Stop".',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _lastWords.isEmpty
                ? const Icon(Icons.mic, size: 48, color: Colors.greenAccent)
                : Text('Heard: "${_lastWords}"', style: const TextStyle(color: Colors.yellowAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _speech.listen(
                onResult: (result) {
                  setStateDialog(() {
                    _lastWords = result.recognizedWords;
                  });
                },
                localeId: 'en_US',
                partialResults: true,
              );
            },
            child: const Text('Start Listening'),
          ),
          TextButton(
            onPressed: () async {
              await _speech.stop();
              setState(() => _listening = false);
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
              await _tts.speak("Okay, cancelled.");
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  setState(() => _listening = false);
}
  Future<void> _startVoiceFlowOld() async {

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Voice Navigate', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Say part of the file name, then press Stop.', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              _lastWords.isEmpty
                  ? const Icon(Icons.mic, size: 48, color: Colors.greenAccent)
                  : Text('Heard: "${_lastWords}"', style: const TextStyle(color: Colors.yellowAccent)),
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
                await _tts.speak("Okay, cancelled.");
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Small utility / cleanup
  // ---------------------------
  @override
  void dispose() {
    try {
      _speech.stop();
      _speech.cancel();
    } catch (_) {}
    _spokenInputController.dispose();
    super.dispose();
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Upload Notes', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.deepPurpleAccent,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onWillPop),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Upload notes manually or use voice to navigate to local files.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Colors.black87, fontWeight: FontWeight.w500)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      backgroundColor: const Color.fromARGB(255, 4, 192, 101),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _startVoiceFlow,
                    icon: const Icon(Icons.mic, size: 28),
                    label: const Text('Use Voice to Navigate'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Small helper class for indexed files
class _IndexedFile {
  final String path;
  final String name; // file name with extension
  final String alias; // spoken alias

  _IndexedFile(this.path, this.name, this.alias);
}
