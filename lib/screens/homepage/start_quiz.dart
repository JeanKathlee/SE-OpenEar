import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class StartQuiz {
  static Future<void> show(BuildContext context) async {
    final FlutterTts flutterTts = FlutterTts();

    // Setup TTS
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.7);
    await flutterTts.awaitSpeakCompletion(false);

    // Speak simultaneously with showing dialog
    flutterTts.speak("You are now in the Start Quiz screen.");

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
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
                  "Start Quiz",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Tap the mic to begin your quiz!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Listening... 🎤")),
                    );
                    flutterTts.speak("Listening...");
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
                    // Stop any ongoing speech, then say closed
                    await flutterTts.stop();
                    await Future.delayed(const Duration(milliseconds: 200));
                    await flutterTts.speak("Quiz closed.");
                    Navigator.pop(context);
                  },
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
