import 'package:flutter/material.dart';
import '/services/TTS_services.dart'; // ✅ Use the shared TTS service

class AskQuestionsPopup {
  static Future<void> show(BuildContext context) async {
    final TtsService tts = TtsService();

    // 🔹 Announce entering the popup
    await tts.stop();
    await tts.speakAndWait("You are now in the Ask Questions screen.");

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
                  "Ask a Question",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Tap the mic and start speaking your question!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Listening... 🎤")),
                    );
                    await tts.stop();
                    await tts.speak("Listening...");
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
                    await Future.delayed(const Duration(milliseconds: 150));
                    await tts.speak("Closing Ask Questions screen.");
                    if (context.mounted) Navigator.pop(context);
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
