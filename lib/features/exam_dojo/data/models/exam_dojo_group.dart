import 'package:cloud_firestore/cloud_firestore.dart';

import 'exam_dojo_subject.dart';

class ExamDojoGroup {
  ExamDojoGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.memberIds,
    required this.adminIds,
    required this.subjects,
    this.updatedAt,
    this.roadmapVersion,
  });

  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> memberIds;
  final List<String> adminIds;
  final List<ExamDojoSubject> subjects;
  final String? roadmapVersion;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'subjects': subjects.map((subject) => subject.toMap()).toList(),
      'roadmapVersion': roadmapVersion,
    };
  }

  factory ExamDojoGroup.fromMap(String id, Map<String, dynamic> map) {
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

    final rawSubjects = (map['subjects'] as List<dynamic>?) ?? const [];
    final subjects = rawSubjects
        .map((item) => item is Map<String, dynamic>
            ? item
            : item is Map
                ? Map<String, dynamic>.from(item)
                : null)
        .whereType<Map<String, dynamic>>()
        .map(ExamDojoSubject.fromMap)
        .toList();
    return ExamDojoGroup(
      id: id,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']),
      memberIds: parseStringList(map['memberIds']),
      adminIds: parseStringList(map['adminIds']),
      subjects: subjects,
      roadmapVersion: map['roadmapVersion']?.toString(),
    );
  }

  ExamDojoGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? memberIds,
    List<String>? adminIds,
    List<ExamDojoSubject>? subjects,
    String? roadmapVersion,
  }) {
    return ExamDojoGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      subjects: subjects ?? this.subjects,
      roadmapVersion: roadmapVersion ?? this.roadmapVersion,
    );
  }
}
