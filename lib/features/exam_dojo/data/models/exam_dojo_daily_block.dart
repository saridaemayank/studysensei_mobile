import 'package:cloud_firestore/cloud_firestore.dart';

class ExamDojoDailyBlock {
  const ExamDojoDailyBlock({
    required this.id,
    required this.date,
    required this.blockType,
    required this.durationMinutes,
    this.subjectId,
    this.subjectName,
    this.chapterId,
    this.chapter,
    this.roadmapRef,
    this.notes,
    this.status,
    this.sessionDate,
    this.dojoId,
  });

  final String id;
  final String date; // YYYY-MM-DD
  final String blockType;
  final int durationMinutes;
  final String? subjectId;
  final String? subjectName;
  final String? chapterId;
  final String? chapter;
  final String? roadmapRef;
  final String? notes;
  final String? status;
  final DateTime? sessionDate;
  final String? dojoId;

  factory ExamDojoDailyBlock.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ExamDojoDailyBlock(
      id: map['id']?.toString() ?? map['blockId']?.toString() ?? '',
      date: map['date']?.toString() ??
          (map['sessionDate'] is Timestamp
              ? (map['sessionDate'] as Timestamp)
                  .toDate()
                  .toIso8601String()
                  .split('T')
                  .first
              : ''),
      subjectId: map['subjectId']?.toString(),
      subjectName: map['subjectName']?.toString() ?? map['subject']?.toString(),
      chapterId: map['chapterId']?.toString() ?? map['chapter_id']?.toString(),
      chapter: map['chapter']?.toString() ?? map['chapterName']?.toString(),
      blockType:
          map['blockType']?.toString() ?? map['type']?.toString() ?? 'Learn',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ??
          (map['expectedMinutes'] as num?)?.toInt() ??
          0,
      roadmapRef: map['roadmapRef']?.toString(),
      notes: map['notes']?.toString() ?? map['description']?.toString(),
      status: map['status']?.toString(),
      sessionDate: parseDate(map['sessionDate']),
      dojoId: map['dojoId']?.toString(),
    );
  }

  ExamDojoDailyBlock copyWith({
    String? id,
    String? date,
    String? blockType,
    int? durationMinutes,
    String? subjectId,
    String? subjectName,
    String? chapterId,
    String? chapter,
    String? roadmapRef,
    String? notes,
    String? status,
    DateTime? sessionDate,
    String? dojoId,
  }) {
    return ExamDojoDailyBlock(
      id: id ?? this.id,
      date: date ?? this.date,
      blockType: blockType ?? this.blockType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      chapterId: chapterId ?? this.chapterId,
      chapter: chapter ?? this.chapter,
      roadmapRef: roadmapRef ?? this.roadmapRef,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      sessionDate: sessionDate ?? this.sessionDate,
      dojoId: dojoId ?? this.dojoId,
    );
  }
}
