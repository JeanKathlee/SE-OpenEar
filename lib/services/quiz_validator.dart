/// Quiz Validator - Determines if content is quizzable
class QuizValidator {
  /// Validates if content is suitable for creating quiz questions
  /// Returns true if content has sufficient educational value
  static bool isQuizzable(String content, String fileName) {
    // Check minimum content length (at least 100 characters)
    if (content.length < 100) {
      return false;
    }

    // Check if content has multiple sentences (at least 3)
    final sentences = content.split(RegExp(r'[.!?]+'));
    if (sentences.where((s) => s.trim().isNotEmpty).length < 3) {
      return false;
    }

    // Check for key educational markers
    final hasKeywords = _hasEducationalContent(content);

    return hasKeywords;
  }

  /// Check if content contains educational markers
  static bool _hasEducationalContent(String content) {
    final lowerContent = content.toLowerCase();

    // Educational keywords
    const keywords = [
      'is', 'are', 'what', 'why', 'how', 'when', 'where', 'which',
      'definition', 'describe', 'explain', 'define', 'concept',
      'chapter', 'section', 'topic', 'subject', 'important',
      'includes', 'consists', 'comprises', 'refers', 'means',
      'the', 'a', 'an', // common articles
    ];

    // Count educational markers
    int markerCount = 0;
    for (final keyword in keywords) {
      if (lowerContent.contains(keyword)) {
        markerCount++;
      }
    }

    // Must have at least 5 educational markers
    return markerCount >= 5;
  }

  /// Get quizzability score (0-100)
  static int getQuizzabilityScore(String content, String fileName) {
    int score = 0;

    // Content length (0-30 points)
    final contentLength = content.length;
    if (contentLength >= 1000) {
      score += 30;
    } else if (contentLength >= 500) {
      score += 20;
    } else if (contentLength >= 200) {
      score += 10;
    }

    // Sentence count (0-30 points)
    final sentences = content.split(RegExp(r'[.!?]+'));
    final sentenceCount = sentences.where((s) => s.trim().isNotEmpty).length;
    if (sentenceCount >= 20) {
      score += 30;
    } else if (sentenceCount >= 10) {
      score += 20;
    } else if (sentenceCount >= 5) {
      score += 10;
    }

    // Educational content (0-40 points)
    final lowerContent = content.toLowerCase();
    const educationMarkers = [
      'important', 'definition', 'explain', 'describe', 'concept',
      'chapter', 'section', 'topic', 'includes', 'consists',
    ];
    int markerCount = 0;
    for (final marker in educationMarkers) {
      if (lowerContent.contains(marker)) {
        markerCount++;
      }
    }
    score += (markerCount * 4).clamp(0, 40).toInt();

    return score.clamp(0, 100);
  }

  /// Get validation message
  static String getValidationMessage(String content, String fileName) {
    if (content.length < 100) {
      return 'File is too short. Minimum 100 characters required.';
    }

    final sentences = content.split(RegExp(r'[.!?]+'));
    if (sentences.where((s) => s.trim().isNotEmpty).length < 3) {
      return 'File has too few sentences. At least 3 sentences required.';
    }

    if (!_hasEducationalContent(content)) {
      return 'File does not contain sufficient educational content.';
    }

    final score = getQuizzabilityScore(content, fileName);
    if (score >= 80) {
      return 'Excellent! This file is highly quizzable.';
    } else if (score >= 60) {
      return 'Good! This file is suitable for quizzing.';
    } else {
      return 'Fair. This file can be used for quizzing.';
    }
  }
}
