import 'dart:convert';

/// Quiz Question Generator - Generates questions from content
class QuizQuestion {
  final String question;
  final List<String> options;  // A, B, C, D
  final String correctAnswer;   // The correct letter (A, B, C, or D)
  final int correctIndex;       // Index of correct answer (0-3)

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.correctIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'correctIndex': correctIndex,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] ?? '',
      correctIndex: map['correctIndex'] ?? 0,
    );
  }
}

class QuestionGenerator {
  /// Generate quiz questions from content
  static List<QuizQuestion> generateQuestions(
    String content,
    String title, {
    int maxQuestions = 5,
  }) {
    final questions = <QuizQuestion>[];

    // Split content into sentences
    final sentences = _splitIntoSentences(content);

    if (sentences.isEmpty) return questions;

    // Generate comprehension questions
    for (int i = 0; i < sentences.length && questions.length < maxQuestions; i++) {
      final sentence = sentences[i].trim();

      if (sentence.length < 30) continue; // Skip too short sentences

      // Generate direct comprehension question
      final question = _generateComprehensionQuestion(sentence, sentences);
      if (question != null) {
        questions.add(question);
      }
    }

    // Generate fill-in-the-blank questions if needed
    for (int i = 0; i < sentences.length && questions.length < maxQuestions; i++) {
      final sentence = sentences[i].trim();
      if (sentence.length < 30) continue;
      
      final q = _generateFillInBlankQuestion(sentence, sentences);
      if (q != null && !questions.any((qu) => qu.question == q.question)) {
        questions.add(q);
      }
    }

    return questions.take(maxQuestions).toList();
  }

  /// Split content into sentences
  static List<String> _splitIntoSentences(String content) {
    return content
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 10)
        .toList();
  }

  /// Generate a comprehension question directly from sentence
  static QuizQuestion? _generateComprehensionQuestion(
    String sentence,
    List<String> allSentences,
  ) {
    final words = sentence.split(' ');
    if (words.length < 5) return null;

    // Common filler words to skip
    const commonWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'is', 'are', 'was', 'were', 'be', 'been', 'have', 'has', 'do',
      'does', 'did', 'by', 'with', 'from', 'as', 'it', 'that', 'this', 'these'
    };

    // Find meaningful words for blank
    final meaningfulWords = <String, int>{};
    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (word.length > 3 && !commonWords.contains(word)) {
        meaningfulWords[word] = i;
      }
    }

    if (meaningfulWords.isEmpty) return null;

    // Pick a word to blank out
    final selectedWord = meaningfulWords.keys.first;
    final selectedIndex = meaningfulWords[selectedWord]!;

    // Create fill-in-the-blank question
    final questionWords = List<String>.from(words);
    questionWords[selectedIndex] = '______';
    final questionText = '${questionWords.join(' ').replaceAll(RegExp(r'[.!?]'), '')}?';

    // Generate options
    final options = _generateMultipleChoiceOptions(selectedWord, allSentences);
    if (options.length < 4) return null;

    // Find correct index
    final correctIndex = options.indexWhere((o) => o.toLowerCase() == selectedWord.toLowerCase());

    return QuizQuestion(
      question: questionText,
      options: options,
      correctAnswer: selectedWord,
      correctIndex: correctIndex,
    );
  }

  /// Generate fill-in-the-blank question from sentence
  static QuizQuestion? _generateFillInBlankQuestion(
    String sentence,
    List<String> allSentences,
  ) {
    if (sentence.length < 40) return null;

    // Extract key information from sentence
    final words = sentence.split(' ');
    if (words.length < 6) return null;

    // Find a noun or significant word
    final significantWord = words.firstWhere(
      (w) => w.length > 4,
      orElse: () => '',
    );

    if (significantWord.isEmpty) return null;

    // Create question: "What does the text tell us about..."
    final cleanWord = significantWord.replaceAll(RegExp(r'[^\w]'), '');
    final question = 'According to the text, what is the main point about "$cleanWord"?';

    // Generate detailed options based on context
    final options = [
      _extractMainPoint(sentence),
      _generateDistractor(sentence, 1),
      _generateDistractor(sentence, 2),
      _generateDistractor(sentence, 3),
    ];

    // Find correct answer index
    const correctIndex = 0;

    return QuizQuestion(
      question: question,
      options: options,
      correctAnswer: options[0],
      correctIndex: correctIndex,
    );
  }

  /// Extract the main point from a sentence
  static String _extractMainPoint(String sentence) {
    final cleaned = sentence.replaceAll(RegExp(r'[.!?]'), '').trim();
    if (cleaned.length > 100) {
      return cleaned.substring(0, 100) + '...';
    }
    return cleaned;
  }

  /// Generate a distractor (wrong answer)
  static String _generateDistractor(String originalSentence, int variant) {
    final words = originalSentence.split(' ');
    final reverseWords = List.from(words.reversed).join(' ').replaceAll(RegExp(r'[.!?]'), '');
    
    switch (variant) {
      case 1:
        return 'The opposite of what the text states';
      case 2:
        return 'Something completely unrelated to the topic';
      case 3:
        return 'A general statement that doesn\'t match the text';
      default:
        return 'An assumption not mentioned in the text';
    }
  }

  /// Generate multiple choice options with correct answer and distractors
  static List<String> _generateMultipleChoiceOptions(
    String correctAnswer,
    List<String> sentences,
  ) {
    final options = <String>[correctAnswer];
    final usedWords = <String>{correctAnswer.toLowerCase()};

    // Extract alternative words from sentences
    for (final sentence in sentences) {
      if (options.length >= 4) break;

      final words = sentence.split(RegExp(r'[\s.!?,;:]+'));
      for (final word in words) {
        if (options.length >= 4) break;
        
        final cleaned = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
        if (cleaned.length > 3 && 
            !usedWords.contains(cleaned) &&
            cleaned != correctAnswer.toLowerCase()) {
          options.add(word.replaceAll(RegExp(r'[^\w]'), ''));
          usedWords.add(cleaned);
        }
      }
    }

    // Fill with generic options if needed
    while (options.length < 4) {
      options.add('Option ${options.length}');
    }

    // Shuffle all options while tracking correct answer position
    final correctAnswerText = options[0];
    final shuffled = options.sublist(1)..shuffle();
    final allOptions = [correctAnswerText, ...shuffled.take(3)];
    
    // Shuffle again for better distribution
    final finalOptions = List<String>.from(allOptions)..shuffle();

    return finalOptions;
  }
}
