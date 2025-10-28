import 'package:flutter/material.dart';

class UploadNotes extends StatelessWidget {
  const UploadNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Notes')),
      body: const Center(
        child: Text(
          'This is the Upload Notes screen.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
