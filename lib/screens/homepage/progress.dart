import 'package:flutter/material.dart';

class Progress extends StatelessWidget {
  const Progress({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const Center(
        child: Text(
          'This is the Progress screen.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
