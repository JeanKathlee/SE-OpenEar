import 'package:flutter/material.dart';

class ReadNotesScreen extends StatelessWidget {
  const ReadNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Temporary placeholder notes; replace with dynamic data later
    final List<String> notes = [
      'Note 1: Introduction to Voice-First Learning',
      'Note 2: Importance of Accessibility in Education',
      'Note 3: Using OpenEar for Interactive Learning',
      'Note 4: Review and Summary',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Notes'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: notes.isEmpty
              ? const Center(
                  child: Text(
                    'No notes available. Upload or add new notes first.',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Card(
                      color: Colors.teal.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          note,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.volume_up,
                          color: Colors.white,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Playing: ${note.split(":").first}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          // TODO: Add Text-to-Speech (TTS) here later
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
