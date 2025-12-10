import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/login_interface.dart';

// add a RouteObserver instance
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    // Firebase configuration for web
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyB7ilZAxJmnqRaixngyQm08_6yw737A2SQ',
        appId: '1:315703175462:web:f1bce7f252b2533a4779e7',
        messagingSenderId: '315703175462',
        projectId: 'openear-app-3dd73',
        authDomain: 'openear-app-3dd73.firebaseapp.com',
        storageBucket: 'openear-app-3dd73.firebasestorage.app',
      ),
    );
  } else {
    // For mobile platforms
    await Firebase.initializeApp();
  }
  
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
      home: const LoginScreen(),

      // Add the RouteObserver to navigatorObservers
      navigatorObservers: [routeObserver],
    );
  }
}
