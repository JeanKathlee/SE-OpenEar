import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class ReadNotesScreen extends StatefulWidget {
  const ReadNotesScreen({super.key});

  @override
  State<ReadNotesScreen> createState() => _ReadNotesScreenState();
}

class _ReadNotesScreenState extends State<ReadNotesScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _hasAnnounced = false;
  bool _isSpeaking = false;
  bool _isClosing = false;
  bool _loading = true;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announce();
      _loadSavedNotes();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasAnnounced = false;
  }

  Future<void> _announce() async {
    if (_hasAnnounced || _isSpeaking) return;
    _isSpeaking = true;
    _hasAnnounced = true;

    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    await _tts.speak(
      'You are now in the Read Notes screen. Tap any note to hear it or press the mic button and say a file name.',
    );

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  Future<void> _loadSavedNotes() async {
    setState(() => _loading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory(
        '${appDir.path}${Platform.pathSeparator}saved_notes',
      );
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }

      final files = notesDir.listSync().whereType<File>().toList();
      final List<Map<String, dynamic>> loaded = [];

      for (final f in files) {
        try {
          final content = await f.readAsString();
          final map = jsonDecode(content) as Map<String, dynamic>;
          map['__path'] = f.path;
          loaded.add(map);
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> uniqueByTitle = {};
      for (final m in loaded) {
        final titleKey = (m['title'] ?? 'untitled')
            .toString()
            .toLowerCase()
            .trim();
        if (!uniqueByTitle.containsKey(titleKey)) {
          uniqueByTitle[titleKey] = m;
        }
      }

      final finalList = uniqueByTitle.values.toList()
        ..sort((a, b) {
          final aCreated = DateTime.tryParse(a['created'] ?? '') ?? DateTime(0);
          final bCreated = DateTime.tryParse(b['created'] ?? '') ?? DateTime(0);
          return bCreated.compareTo(aCreated);
        });

      setState(() {
        _notes = finalList;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _speakNote(Map<String, dynamic> note) async {
    final text = (note['content'] ?? '').toString();
    if (text.isEmpty) {
      await _tts.speak('This note is empty.');
      return;
    }
    await _tts.stop();
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      await _tts.speak('Microphone permission is required.');
      return false;
    }
    return true;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesTitle(String title, String query) {
    final nTitle = _normalize(title);
    final nQuery = _normalize(query);
    if (nQuery.isEmpty) return false;
    if (nTitle.contains(nQuery)) return true;

    final queryTokens = nQuery.split(' ');
    final titleTokens = nTitle.split(' ');
    return queryTokens.every((t) => titleTokens.any((tt) => tt.contains(t)));
  }

  Future<void> _listenAndPlay() async {
    final ok = await _requestMicPermission();
    if (!ok) return;

    final available = await _speech.initialize();
    if (!available) {
      await _tts.speak('Speech recognition not available.');
      return;
    }

    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(
      'Which file would you like me to read? Say part of the file name after the beep.',
    );

    await Future.delayed(const Duration(milliseconds: 300));

    String heard = '';
    bool finalReceived = false;
    final completer = Completer<void>();

    _speech.listen(
      onResult: (result) {
        final recognized = result.recognizedWords.trim();
        if (recognized.isNotEmpty) heard = recognized;
        if (result.finalResult && !finalReceived) {
          finalReceived = true;
          if (!completer.isCompleted) completer.complete();
        }
      },
      localeId: 'en_US',
      partialResults: true,
    );

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 10)),
    ]);

    try {
      await _speech.stop();
    } catch (_) {}

    if (heard.trim().isEmpty) {
      await _tts.speak('No voice detected.');
      return;
    }

    final query = heard.toLowerCase();
    if (query.contains('go back') ||
        query.contains('exit') ||
        query.contains('close')) {
      await _handleExit(); // ✅ identical voice behavior as back button
      return;
    }

    Map<String, dynamic>? found;
    for (final n in _notes) {
      final title = (n['title'] ?? '').toString();
      if (_matchesTitle(title, query)) {
        found = n;
        break;
      }
    }

    if (found == null) {
      await _tts.speak('No note matched that name.');
      return;
    }

    await _tts.speak('Opening ${found['title']}');
    await _speakNote(found);
  }

  Future<void> _handleExit() async {
    if (_isClosing) return;
    _isClosing = true;

    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.6);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    final completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    await _tts.speak('Closing Read Notes screen.');
    await completer.future;

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Read Notes'),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
              ? const Center(
                  child: Text(
                    'No notes available. Upload or add new notes first.',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final title = (note['title'] ?? 'Untitled').toString();
                    return Card(
                      color: Colors.teal.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.volume_up,
                          color: Colors.white,
                        ),
                        onTap: () async {
                          await _tts.speak('Playing $title');
                          await _speakNote(note);
                        },
                      ),
                    );
                  },
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _listenAndPlay,
          child: const Icon(Icons.mic),
          tooltip: 'Say file name to read',
        ),
      ),
    );
  }
}
