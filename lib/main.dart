import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart'; // ✅ We now load the screen from a separate file

void main() {
  runApp(const OpenEarApp());
}

class OpenEarApp extends StatelessWidget {
  const OpenEarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenEar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const WelcomeScreen(), // ✅ Starting screen is now external
    );
  }
}
