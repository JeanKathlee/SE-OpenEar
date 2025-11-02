import 'package:flutter/material.dart';
import '../screens/homepage/start_quiz.dart';

class QuizEngine extends StatefulWidget {
  const QuizEngine({super.key});

  @override
  State<QuizEngine> createState() => _QuizEngineState();
}

class _QuizEngineState extends State<QuizEngine> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Flutter is developed by which company?',
      'options': ['Apple', 'Google', 'Microsoft', 'Amazon'],
      'answer': 'Google',
    },
    {
      'question': 'Dart is a programming language used for Flutter.',
      'options': ['True', 'False'],
      'answer': 'True',
    },
  ];

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final correct =
        _selectedAnswer == _questions[_currentQuestionIndex]['answer'];
    if (correct) _score++;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(correct ? '✅ Correct!' : '❌ Incorrect.'),
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Quiz Completed!'),
        content: Text(
          'Your score: $_score / ${_questions.length}',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close results dialog
              Navigator.pop(context); // Back to Start Quiz screen
            },
            child: const Text('Back to Quiz Menu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Question Header
              Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Question Text
              Text(
                question['question'],
                style: const TextStyle(fontSize: 18, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Answer Options
              ...List.generate((question['options'] as List).length, (index) {
                final option = question['options'][index];
                final selected = _selectedAnswer == option;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _selectedAnswer = option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected
                          ? Colors.blueAccent
                          : Colors.grey[300],
                      foregroundColor: selected ? Colors.white : Colors.black,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),

              const Spacer(),

              // Submit & Next Buttons
              ElevatedButton.icon(
                onPressed: _submitAnswer,
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'Submit Answer',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.skip_next),
                label: const Text(
                  'Next Question',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
