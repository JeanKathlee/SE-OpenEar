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
  Map<String, List<Map<String, dynamic>>> _groupedProgress = {};

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
        
        // Group by file title
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final item in list) {
          final title = item['title'] ?? 'Untitled';
          if (!grouped.containsKey(title)) {
            grouped[title] = [];
          }
          grouped[title]!.add(item);
        }
        
        setState(() {
          _progress = list;
          _groupedProgress = grouped;
          _loading = false;
        });
      } else {
        setState(() {
          _progress = [];
          _groupedProgress = {};
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _progress = [];
        _groupedProgress = {};
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
            : _groupedProgress.isEmpty
                ? const Center(
                    child: Text(
                      'No quiz progress yet. Take a quiz to see results here.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedProgress.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final fileTitle = _groupedProgress.keys.elementAt(index);
                      final attempts = _groupedProgress[fileTitle]!;
                      
                      // Calculate stats
                      final totalAttempts = attempts.length;
                      final bestScore = attempts.map((a) => a['percent'] ?? 0).reduce((a, b) => a > b ? a : b);
                      final avgScore = (attempts.map((a) => a['percent'] ?? 0).reduce((a, b) => a + b) / totalAttempts).round();
                      final latestAttempt = attempts.first;
                      
                      Color badgeColor;
                      Color darkBadgeColor;
                      if (bestScore >= 80) {
                        badgeColor = Colors.green.shade400;
                        darkBadgeColor = Colors.white;
                      } else if (bestScore >= 60) {
                        badgeColor = Colors.orange.shade400;
                        darkBadgeColor = Colors.white;
                      } else {
                        badgeColor = Colors.red.shade400;
                        darkBadgeColor = Colors.white;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: badgeColor.withOpacity(0.5), width: 2),
                        ),
                        elevation: 6,
                        color: Colors.white,
                        shadowColor: badgeColor.withOpacity(0.3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showFileHistory(fileTitle, attempts),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [badgeColor, badgeColor.withOpacity(0.8)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: badgeColor.withOpacity(0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.white, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Best: $bestScore%',
                                            style: TextStyle(
                                              color: darkBadgeColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.blue.shade400, Colors.blue.shade500],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.trending_up, color: Colors.white, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Avg: $avgScore%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  fileTitle,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.quiz, size: 22, color: Colors.deepPurple.shade400),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$totalAttempts ${totalAttempts == 1 ? 'attempt' : 'attempts'}',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_forward_ios, size: 18, color: Colors.deepPurple.shade400),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showFileHistory(String fileTitle, List<Map<String, dynamic>> attempts) async {
    await tts.speak('Showing quiz history for $fileTitle');
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fileTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${attempts.length} ${attempts.length == 1 ? 'attempt' : 'attempts'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: attempts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final attempt = attempts[index];
                  final percent = attempt['percent'] ?? 0;
                  final score = attempt['score'] ?? 0;
                  final total = attempt['total'] ?? 0;
                  final timestamp = attempt['timestamp'] ?? '';
                  
                  String dateLabel = '';
                  String timeAgo = '';
                  try {
                    final date = DateTime.parse(timestamp);
                    dateLabel = DateFormat('MMM d, yyyy – h:mm a').format(date);
                    
                    final diff = DateTime.now().difference(date);
                    if (diff.inMinutes < 1) {
                      timeAgo = 'Just now';
                    } else if (diff.inHours < 1) {
                      timeAgo = '${diff.inMinutes}m ago';
                    } else if (diff.inDays < 1) {
                      timeAgo = '${diff.inHours}h ago';
                    } else if (diff.inDays < 7) {
                      timeAgo = '${diff.inDays}d ago';
                    } else {
                      timeAgo = DateFormat('MMM d').format(date);
                    }
                  } catch (_) {}

                  Color badgeColor;
                  Color badgeColorLight;
                  String gradeLabel;
                  IconData gradeIcon;
                  if (percent >= 80) {
                    badgeColor = Colors.green.shade500;
                    badgeColorLight = Colors.green.shade400;
                    gradeLabel = 'Excellent';
                    gradeIcon = Icons.emoji_events;
                  } else if (percent >= 60) {
                    badgeColor = Colors.orange.shade500;
                    badgeColorLight = Colors.orange.shade400;
                    gradeLabel = 'Good';
                    gradeIcon = Icons.thumb_up;
                  } else if (percent >= 40) {
                    badgeColor = Colors.amber.shade600;
                    badgeColorLight = Colors.amber.shade400;
                    gradeLabel = 'Fair';
                    gradeIcon = Icons.school;
                  } else {
                    badgeColor = Colors.red.shade500;
                    badgeColorLight = Colors.red.shade400;
                    gradeLabel = 'Needs Work';
                    gradeIcon = Icons.replay;
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: badgeColor.withOpacity(0.5), width: 2),
                    ),
                    elevation: 4,
                    color: Colors.white,
                    shadowColor: badgeColor.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [badgeColor, badgeColorLight],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: badgeColor.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$percent%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(gradeIcon, color: badgeColor, size: 22),
                                        const SizedBox(width: 6),
                                        Text(
                                          gradeLabel,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Score: $score / $total',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              if (index == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Latest',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo,
                                style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 12),
                              if (dateLabel.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
