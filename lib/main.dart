import 'package:flutter/material.dart';
import 'screens/login_interface.dart';

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
        scaffoldBackgroundColor: const Color(0xFF384A5F),
        primaryColor: const Color(0xFF90AFC5),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 22.0, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 18.0, color: Colors.white70),
        ),
      ),
      home: LoginScreen(),
    );
  }
}
