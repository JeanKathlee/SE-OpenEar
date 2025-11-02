import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// ✅ Shared TTS service
import '/services/TTS_services.dart';

class ReadNotesScreen extends StatefulWidget {
  const ReadNotesScreen({super.key});

  @override
  State<ReadNotesScreen> createState() => _ReadNotesScreenState();
}

class _ReadNotesScreenState extends State<ReadNotesScreen> {
  final TtsService tts = TtsService();
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

    await tts.stop();
    await tts.speakAndWait(
      'You are now in the Read Notes screen. Tap any note to hear it or press the mic button and say a file name.',
    );

    _isSpeaking = false;
  }

  Future<void> _loadSavedNotes() async {
    setState(() => _loading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${appDir.path}/saved_notes');

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
        uniqueByTitle.putIfAbsent(titleKey, () => m);
      }

      final finalList = uniqueByTitle.values.toList()
        ..sort((a, b) {
          final aCreated = DateTime.tryParse(a['created'] ?? '') ?? DateTime(0);
          final bCreated = DateTime.tryParse(b['created'] ?? '') ?? DateTime(0);
          return bCreated.compareTo(aCreated);
        });

      if (mounted) {
        setState(() {
          _notes = finalList;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _speakNote(Map<String, dynamic> note) async {
    final text = (note['content'] ?? '').toString();
    if (text.isEmpty) {
      await tts.speak('This note is empty.');
      return;
    }

    await tts.stop();
    await tts.speakAndWait(text);
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      await tts.speak('Microphone permission is required.');
      return false;
    }
    return true;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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
      await tts.speak('Speech recognition not available.');
      return;
    }

    await tts.stop();
    await tts.speakAndWait(
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
      await tts.speak('No voice detected.');
      return;
    }

    final query = heard.toLowerCase();
    if (query.contains('go back') ||
        query.contains('exit') ||
        query.contains('close')) {
      await _handleExit();
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
      await tts.speak('No note matched that name.');
      return;
    }

    await tts.speakAndWait('Opening ${found['title']}');
    await _speakNote(found);
  }

  Future<void> _handleExit() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      await _speech.stop();
      await tts.stop();
      await tts.speakAndWait('Closing Read Notes screen.');
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleExit();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Read Notes'),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExit,
          ),
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
                          await tts.speakAndWait('Playing $title');
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
