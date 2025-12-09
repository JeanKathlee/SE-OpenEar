import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '/services/TTS_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class AskQuestionsPopup {
  static Future<void> show(BuildContext context) async {
    final TtsService tts = TtsService();
    final stt.SpeechToText speech = stt.SpeechToText();

    bool isListening = false;

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

    // Search all notes and return best matching line/paragraph
    Future<String?> searchNotes(List<String> keywords) async {
      final notes = await loadSavedNotesText();
      if (notes.isEmpty) return null;

      String? bestMatch;
      int highestScore = 0;

      for (final noteContent in notes) {
        final lines = noteContent.split(RegExp(r'[\n\r•\-\d]+\s*'));
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final lcLine = line.toLowerCase();
          int score = 0;
          for (final kw in keywords) {
            if (lcLine.contains(kw)) score++;
          }
          if (score > highestScore) {
            highestScore = score;
            bestMatch = line.trim();
          }
        }
      }
      return bestMatch;
    }

    // Listen to user question
    Future<void> startListening() async {
      if (isListening) return;
      isListening = true;

      // Request microphone permission
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          await tts.speak(
            "Microphone permission is required to ask questions.",
          );
          isListening = false;
          return;
        }
      }

      // Initialize speech
      final available = await speech.initialize(
        onError: (err) => print("Speech error: $err"),
        onStatus: (status) => print("Speech status: $status"),
      );
      if (!available) {
        await tts.speak("Speech recognition is not available on this device.");
        isListening = false;
        return;
      }

      await tts.stop();
      await tts.speakAndWait("Listening. Please ask your question.");

      String heard = "";
      bool done = false;

      // Timeout in case no speech is detected
      Future.delayed(const Duration(seconds: 15), () async {
        if (!done) {
          await speech.stop();
          await tts.speak("I did not hear anything. Please try again.");
          isListening = false;
        }
      });

      // Start listening
      await speech.listen(
        onResult: (result) async {
          heard = result.recognizedWords;
          if (result.finalResult && !done) {
            done = true;
            await speech.stop();

            if (heard.isEmpty) {
              await tts.speak("I did not hear anything. Please try again.");
              isListening = false;
              return;
            }

            final keywords = extractKeywords(heard);
            final found = await searchNotes(keywords);

            if (found == null) {
              await tts.speak(
                "I cannot find anything related to your question in your notes.",
              );
            } else {
              await tts.speak("Here is what I found:");
              await tts.speakAndWait(found);
              await tts.speak("That's the answer to your question.");
            }
            isListening = false;
          }
        },
        localeId: 'en_US',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 2),
      );
    }

    // Entry TTS
    await tts.stop();
    await tts.speakAndWait("You are now in the Ask Questions screen.");

    // Show dialog
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
                "Tap the mic and ask your question. You can ask multiple questions without closing.",
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
