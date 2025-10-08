import 'package:flutter/material.dart';

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String? imageUrl;
  final String questionType; // 'mcq' or 'numerical'

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    this.imageUrl,
    this.questionType = 'mcq', // Default to MCQ
  });
}

class SenseiQuiz {
  final String id;
  final String lessonId;
  final List<QuizQuestion> questions;
  final int totalQuestions;
  final int correctAnswers;
  final DateTime completedAt;
  final Duration timeSpent;
  final Map<String, dynamic>? metadata;

  SenseiQuiz({
    required this.id,
    required this.lessonId,
    required this.questions,
    required this.totalQuestions,
    required this.correctAnswers,
    DateTime? completedAt,
    Duration? timeSpent,
    this.metadata,
  })  : completedAt = completedAt ?? DateTime.now(),
        timeSpent = timeSpent ?? Duration.zero;

  double get score => totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
  bool get isPerfect => score == 1.0;
  String get formattedScore => '${(score * 100).toInt()}%';

  Color get scoreColor {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

class QuizAttempt {
  final String questionId;
  final int selectedOptionIndex;
  final bool isCorrect;
  final Duration timeSpent;

  const QuizAttempt({
    required this.questionId,
    required this.selectedOptionIndex,
    required this.isCorrect,
    required this.timeSpent,
  });
}

class QuizStatistics {
  final int totalQuizzes;
  final int totalQuestions;
  final int correctAnswers;
  final double averageScore;
  final String bestSubject;
  final String weakestSubject;
  final Map<String, int> subjectScores;
  final Duration totalStudyTime;

  const QuizStatistics({
    this.totalQuizzes = 0,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.averageScore = 0.0,
    this.bestSubject = '',
    this.weakestSubject = '',
    this.subjectScores = const {},
    this.totalStudyTime = Duration.zero,
  });

  double get accuracy => totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
  String get formattedAccuracy => '${(accuracy * 100).toStringAsFixed(1)}%';
}
