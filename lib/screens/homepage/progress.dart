import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/TTS_services.dart'; // ✅ Use shared TTS service

class Progress extends StatefulWidget {
  const Progress({super.key});

  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final TtsService tts = TtsService();
  bool _isClosing = false;
  bool _loading = true;
  List<Map<String, dynamic>> _progress = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProgress();
      await _announce();
    });
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('quiz_progress');
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _progress = list;
          _loading = false;
        });
      } else {
        setState(() {
          _progress = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _progress = [];
        _loading = false;
      });
      debugPrint('Failed to load progress: $e');
    }
  }

  Future<void> _announce() async {
    await tts.stop();
    await tts.speakAndWait('You are now in the Progress screen.');
  }

  Future<bool> _onWillPop() async {
    if (_isClosing) return false;
    _isClosing = true;

    try {
      await tts.stop();
      await Future.delayed(const Duration(milliseconds: 150));
      await tts.speak('Closing Progress screen.');
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
    return false; // Prevent double pop
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onWillPop,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _progress.isEmpty
                ? const Center(
                    child: Text(
                      'No quiz progress yet. Take a quiz to see results here.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _progress.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _progress[index];
                      final percent = item['percent'] ?? 0;
                      final score = item['score'] ?? 0;
                      final total = item['total'] ?? 0;
                      final title = item['title'] ?? 'Untitled';
                      final timestamp = item['timestamp'] ?? '';
                      String dateLabel = '';
                      try {
                        dateLabel = DateFormat('MMM d, yyyy – h:mm a')
                            .format(DateTime.parse(timestamp));
                      } catch (_) {}

                      Color badgeColor;
                      if (percent >= 80) {
                        badgeColor = Colors.green;
                      } else if (percent >= 60) {
                        badgeColor = Colors.orange;
                      } else {
                        badgeColor = Colors.red;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: badgeColor.withOpacity(0.3)),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$percent%',
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Score: $score / $total',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              if (dateLabel.isNotEmpty)
                                Text(
                                  dateLabel,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
