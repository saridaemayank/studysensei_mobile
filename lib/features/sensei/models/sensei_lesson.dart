class SenseiLesson {
  final String id;
  final String title;
  final String subject;
  final String videoUrl;
  final String hook;
  final List<ConceptMapping> conceptMappings;
  final String analogy;
  final String narrationScript;
  final List<QuizQuestion> quizQuestions;
  final DateTime createdAt;

  SenseiLesson({
    required this.id,
    required this.title,
    required this.subject,
    required this.videoUrl,
    required this.hook,
    required this.conceptMappings,
    required this.analogy,
    required this.narrationScript,
    List<QuizQuestion>? quizQuestions,
    DateTime? createdAt,
  })  : quizQuestions = quizQuestions ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get hasQuiz => quizQuestions.isNotEmpty;
}

class ConceptMapping {
  final String title;
  final String description;
  final String? timestamp;

  const ConceptMapping({
    required this.title,
    required this.description,
    this.timestamp,
  });
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
  });

  bool isCorrect(int selectedIndex) => selectedIndex == correctOptionIndex;
}
