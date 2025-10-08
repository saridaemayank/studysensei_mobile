import 'package:cloud_firestore/cloud_firestore.dart';

class SenseiSession {
  final String id;
  final String subject;
  final List<String> concepts;
  final String? videoUrl;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final bool isFaceBlurred;
  final bool isMuted;
  final String? languageCode;
  final String? voiceId;
  final String? title;
  final String? hook;
  final List<Map<String, dynamic>>? conceptMappings;
  final String? analogy;
  final String? narrationScript;
  final String? analysis;
  final List<Map<String, dynamic>>? quizQuestions;
  final bool isProcessed;
  final String? summary;

  SenseiSession({
    required this.id,
    required this.subject,
    required this.concepts,
    this.videoUrl,
    this.thumbnailUrl,
    DateTime? createdAt,
    this.isFaceBlurred = false,
    this.isMuted = false,
    this.languageCode,
    this.voiceId,
    this.title,
    this.hook,
    this.conceptMappings,
    this.analogy,
    this.narrationScript,
    this.analysis,
    this.quizQuestions,
    this.isProcessed = false,
    this.summary,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SenseiSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseCreatedAt(dynamic createdAt) {
      if (createdAt == null) return null;
      if (createdAt is DateTime) return createdAt;
      if (createdAt is String) return DateTime.parse(createdAt);
      if (createdAt is Timestamp) return createdAt.toDate();
      return null;
    }

    return SenseiSession(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      concepts: List<String>.from(json['concepts'] ?? []),
      videoUrl: json['videoUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      createdAt: parseCreatedAt(json['createdAt']),
      isFaceBlurred: json['isFaceBlurred'] ?? false,
      isMuted: json['isMuted'] ?? false,
      languageCode: json['languageCode'],
      voiceId: json['voiceId'],
      title: json['title'],
      hook: json['hook'],
      conceptMappings: json['conceptMappings'] != null
          ? List<Map<String, dynamic>>.from(json['conceptMappings'])
          : null,
      analogy: json['analogy'],
      narrationScript: json['narrationScript'],
      analysis: json['analysis'],
      // Handle both quiz_questions and quizQuestions keys for backward compatibility
      quizQuestions: (json['quiz_questions'] ?? json['quizQuestions']) != null
          ? List<Map<String, dynamic>>.from(
              json['quiz_questions'] ?? json['quizQuestions'] ?? [],
            )
          : null,
      isProcessed: json['isProcessed'] ?? false,
      summary: json['summary'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'concepts': concepts,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
      'isFaceBlurred': isFaceBlurred,
      'isMuted': isMuted,
      'languageCode': languageCode,
      'voiceId': voiceId,
      'title': title,
      'hook': hook,
      'conceptMappings': conceptMappings,
      'analogy': analogy,
      'narrationScript': narrationScript,
      'analysis': analysis,
      'quiz_questions':
          quizQuestions, // Using snake_case for consistency with the API
      'isProcessed': isProcessed,
      'summary': summary,
    };
  }

  SenseiSession copyWith({
    String? id,
    String? subject,
    List<String>? concepts,
    String? videoUrl,
    String? thumbnailUrl,
    DateTime? createdAt,
    bool? isFaceBlurred,
    bool? isMuted,
    String? languageCode,
    String? voiceId,
    String? title,
    String? hook,
    List<Map<String, dynamic>>? conceptMappings,
    String? analogy,
    String? narrationScript,
    String? analysis,
    List<Map<String, dynamic>>? quizQuestions,
    bool? isProcessed,
  }) {
    return SenseiSession(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      concepts: concepts ?? List.from(this.concepts),
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      isFaceBlurred: isFaceBlurred ?? this.isFaceBlurred,
      isMuted: isMuted ?? this.isMuted,
      languageCode: languageCode ?? this.languageCode,
      voiceId: voiceId ?? this.voiceId,
      title: title ?? this.title,
      hook: hook ?? this.hook,
      conceptMappings: conceptMappings ?? this.conceptMappings,
      analogy: analogy ?? this.analogy,
      narrationScript: narrationScript ?? this.narrationScript,
      analysis: analysis ?? this.analysis,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }
}
