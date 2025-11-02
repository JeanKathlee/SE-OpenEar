import 'package:flutter/material.dart';
import '/services/TTS_services.dart'; // ✅ Shared TTS service
import '/services/quiz_engine.dart'; // ✅ Correct import — QuizEngine class is here

class StartQuiz {
  static Future<void> show(BuildContext context) async {
    final TtsService tts = TtsService();

    // 🔹 Announce entering the Start Quiz screen
    await tts.stop();
    await tts.speakAndWait("You are now in the Start Quiz screen.");

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

                // 🎤 Mic Button
                GestureDetector(
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Listening... 🎤")),
                    );
                    await tts.stop();
                    await tts.speak("Starting your quiz now.");

                    // ⏳ Small delay for smooth transition
                    await Future.delayed(const Duration(milliseconds: 400));

                    // ✅ Navigate to QuizEngine screen
                    if (context.mounted) {
                      Navigator.pop(context); // close dialog first
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuizEngine()),
                      );

                      // 🔊 After returning
                      await tts.speak("You are back in the home screen.");
                    }
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

                // ❌ Close Button
                TextButton(
                  onPressed: () async {
                    await tts.stop();
                    await Future.delayed(const Duration(milliseconds: 150));
                    await tts.speak("Closing Start Quiz screen.");
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
