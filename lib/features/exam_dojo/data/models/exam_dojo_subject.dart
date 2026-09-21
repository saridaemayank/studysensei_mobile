import 'package:cloud_firestore/cloud_firestore.dart';

class ExamDojoSubject {
  ExamDojoSubject({
    required this.id,
    required this.name,
    required this.examDate,
    required this.chapters,
    this.estimatedEffort,
    this.difficulty,
  });

  final String id;
  final String name;
  final DateTime examDate;
  final List<String> chapters;
  final String? estimatedEffort;
  final String? difficulty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'examDate': Timestamp.fromDate(examDate),
      'chapters': chapters,
      'estimatedEffort': estimatedEffort,
      'difficulty': difficulty,
    };
  }

  factory ExamDojoSubject.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value
            .where((item) => item != null)
            .map((item) => item.toString())
            .toList();
      }
      return [];
    }

    return ExamDojoSubject(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      examDate: parseDate(map['examDate']) ?? DateTime.now(),
      chapters: parseStringList(map['chapters']),
      estimatedEffort: map['estimatedEffort']?.toString(),
      difficulty: map['difficulty']?.toString(),
    );
  }

  ExamDojoSubject copyWith({
    String? id,
    String? name,
    DateTime? examDate,
    List<String>? chapters,
    String? estimatedEffort,
    String? difficulty,
  }) {
    return ExamDojoSubject(
      id: id ?? this.id,
      name: name ?? this.name,
      examDate: examDate ?? this.examDate,
      chapters: chapters ?? this.chapters,
      estimatedEffort: estimatedEffort ?? this.estimatedEffort,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
