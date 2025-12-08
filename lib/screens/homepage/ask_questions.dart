import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '/services/TTS_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AskQuestionsPopup {
  static Future<void> show(BuildContext context) async {
    final TtsService tts = TtsService();
    final stt.SpeechToText speech = stt.SpeechToText();

    // Load saved notes dynamically (mobile or web)
    Future<List<String>> loadSavedNotesText() async {
      final List<String> results = [];

      if (kIsWeb) {
        try {
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
        } catch (_) {}
        return results;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${appDir.path}/saved_notes');
      if (!await notesDir.exists()) return results;

      final files = notesDir.listSync().whereType<File>();
      for (final f in files) {
        try {
          final data = jsonDecode(await f.readAsString());
          if (data['content'] != null) results.add(data['content'].toString());
        } catch (_) {}
      }
      return results;
    }

    // Extract keywords from user question
    String extractKeyword(String question) {
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
      ];
      final words = question.toLowerCase().split(RegExp(r'\s+'));
      final filtered = words.where((w) => !stopWords.contains(w)).toList();
      return filtered.isEmpty ? question : filtered.join(' ');
    }

    // Search all notes and return best matching sentence
    Future<String?> searchNotes(String keyword) async {
      final notes = await loadSavedNotesText();
      if (notes.isEmpty) return null;

      keyword = keyword.toLowerCase();
      for (final noteContent in notes) {
        final sentences = noteContent.split(RegExp(r'[.!?]'));
        for (final sentence in sentences) {
          if (sentence.toLowerCase().contains(keyword)) {
            return sentence.trim();
          }
        }
      }
      return null;
    }

    // Listen to user question
    Future<void> startListening() async {
      final available = await speech.initialize();
      if (!available) {
        await tts.speak("Speech recognition is not available.");
        return;
      }

      String heard = "";
      await tts.stop();
      await tts.speakAndWait("Listening. Please ask your question.");

      speech.listen(
        onResult: (result) {
          heard = result.recognizedWords;
        },
        localeId: 'en_US',
      );

      await Future.delayed(const Duration(seconds: 5));
      await speech.stop();

      if (heard.isEmpty) {
        await tts.speak("I did not hear anything.");
        return;
      }

      final keyword = extractKeyword(heard);
      final found = await searchNotes(keyword);

      if (found == null) {
        await tts.speak(
          "I cannot find anything related to your question in your notes.",
        );
      } else {
        await tts.speak("Here is what I found:");
        await tts.speakAndWait(found);
      }
    }

    // Entry TTS
    await tts.stop();
    await tts.speakAndWait("You are now in the Ask Questions screen.");

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                "Tap the mic and ask your question.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Listening... 🎤")),
                  );
                  await startListening();
                },
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
                  await tts.stop();
                  await tts.speak("Closing Ask Questions screen.");
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
    );
  }
}
