import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '/services/TTS_services.dart';

class ReadNotesScreen extends StatefulWidget {
  const ReadNotesScreen({super.key, this.openAskQuestions = false});

  final bool openAskQuestions;

  /// Helper to directly show Ask Questions from anywhere
  static Future<void> showAskQuestions(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReadNotesScreen(openAskQuestions: true),
      ),
    );
  }

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

      // Open Ask Questions if requested
      if (widget.openAskQuestions) {
        _showAskQuestions();
      }
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
      List<Map<String, dynamic>> loaded = [];

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final notesJson = prefs.getString('openear_saved_notes');

        if (notesJson != null && notesJson.isNotEmpty) {
          final decoded = jsonDecode(notesJson);
          if (decoded is List) loaded = decoded.cast<Map<String, dynamic>>();
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final notesDir = Directory('${appDir.path}/saved_notes');

        if (!await notesDir.exists()) await notesDir.create(recursive: true);

        final files = notesDir.listSync().whereType<File>().toList();
        for (final f in files) {
          try {
            final content = await f.readAsString();
            final map = jsonDecode(content) as Map<String, dynamic>;
            map['__path'] = f.path;
            loaded.add(map);
          } catch (_) {}
        }
      }

      // Remove duplicates by title
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

    if (mounted) Navigator.of(context).pop();
  }

  // ----------------------
  // Ask Questions Logic
  // ----------------------
  Future<void> _showAskQuestions() async {
    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;
    bool isSpeaking = false;
    bool stopRequested = false;

    Future<List<String>> loadSavedNotesText() async {
      final List<String> results = [];
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final notesJson = prefs.getString('openear_saved_notes');
        if (notesJson != null && notesJson.isNotEmpty) {
          final decoded = jsonDecode(notesJson);
          if (decoded is List) {
            for (var note in decoded) {
              if (note['content'] != null)
                results.add(note['content'].toString());
            }
          }
        }
        return results;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${appDir.path}/saved_notes');
      if (!await notesDir.exists()) return results;

      for (final f in notesDir.listSync().whereType<File>()) {
        try {
          final content = await f.readAsString();
          final data = jsonDecode(content);
          if (data is Map<String, dynamic> && data['content'] != null) {
            results.add(data['content'].toString());
          }
        } catch (_) {}
      }
      return results;
    }

    List<String> extractKeywords(String question) {
      final stopWords = [
        'what',
        'is',
        'are',
        'the',
        'explain',
        'define',
        'meaning',
        'of',
        'tell',
        'me',
        'about',
        'please',
        'can',
        'you',
        'give',
        'show',
      ];
      final words = question.toLowerCase().split(RegExp(r'\s+'));
      return words.where((w) => !stopWords.contains(w)).toList();
    }

    Future<String?> searchNotes(
      List<String> keywords,
      String fullQuestion,
    ) async {
      final notes = await loadSavedNotesText();
      if (notes.isEmpty || keywords.isEmpty) return null;

      String? bestMatch;
      double highestScore = 0.0;

      for (final noteContent in notes) {
        final lines = noteContent.split(RegExp(r'[\n\r•\-\d]+\s*'));
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final lcLine = line.toLowerCase();

          int exactMatches = 0;
          for (final kw in keywords) {
            if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(lcLine))
              exactMatches++;
          }

          double score = exactMatches / keywords.length;
          final questionWords = fullQuestion.toLowerCase().split(
            RegExp(r'\s+'),
          );
          int commonWords = 0;
          for (final qw in questionWords) {
            if (lcLine.contains(qw)) commonWords++;
          }
          double questionScore = commonWords / questionWords.length;
          score += 0.3 * questionScore;

          if (score > highestScore) {
            highestScore = score;
            bestMatch = line.trim();
          }
        }
      }

      return highestScore >= 0.6 ? bestMatch : null;
    }

    Future<void> startListening() async {
      if (isListening) return;
      isListening = true;
      stopRequested = false;
      String heard = '';
      bool finalReceived = false;

      if (speech.isListening) await speech.stop();

      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        await tts.speak("Microphone permission is required to ask questions.");
        isListening = false;
        return;
      }

      final available = await speech.initialize();
      if (!available) {
        await tts.speak("Speech recognition is not available on this device.");
        isListening = false;
        return;
      }

      await tts.stop();
      await tts.speakAndWait("Listening. Ask your question.");

      speech.listen(
        onResult: (result) async {
          heard = result.recognizedWords;
          if (!result.finalResult || finalReceived || stopRequested) return;

          finalReceived = true;
          await speech.stop();

          if (heard.trim().isEmpty) {
            await tts.speak("I did not hear anything. Please try again.");
            isListening = false;
            return;
          }

          final keywords = extractKeywords(heard);
          final found = await searchNotes(keywords, heard);

          if (stopRequested) {
            isListening = false;
            return;
          }

          isSpeaking = true;
          await tts.stop();

          String response = (found == null || found.isEmpty)
              ? "I cannot find anything related to your question in your notes."
              : "Here is what I found: $found. That's the answer to your question.";

          await tts.speakAndWait(response);
          isSpeaking = false;
          isListening = false;
        },
        partialResults: true,
        localeId: 'en_US',
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 3),
      );
    }

    await tts.stop();
    await tts.speakAndWait("You are now in Ask Questions mode.");

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Ask a Question",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Tap the mic and ask your question. You can ask multiple questions without closing.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: startListening,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () async {
                    stopRequested = true;
                    isSpeaking = false;
                    isListening = false;
                    await tts.stop();
                    if (speech.isListening) await speech.stop();
                  },
                  child: const Text(
                    "Stop",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    stopRequested = true;
                    isSpeaking = false;
                    isListening = false;
                    await tts.stop();
                    if (speech.isListening) await speech.stop();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          final title = (note['title'] ?? 'Untitled')
                              .toString();
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
                                  color: Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                              trailing: const Icon(
                                Icons.volume_up,
                                color: Color.fromARGB(255, 255, 254, 254),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _showAskQuestions,
                        icon: const Icon(Icons.question_answer),
                        label: const Text("Ask a Question"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            223,
                            222,
                            224,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
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
