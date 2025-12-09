import 'package:cloud_firestore/cloud_firestore.dart';

class StudySession {
  final String id;
  final String userId;
  final String? studyBlockId;
  final String? assignmentId;
  final String? goalId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedDurationMinutes;
  final int actualDurationMinutes;
  final double completionRatio;
  final String completionStatus;

  const StudySession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.plannedDurationMinutes,
    this.studyBlockId,
    this.assignmentId,
    this.goalId,
    this.endedAt,
    this.actualDurationMinutes = 0,
    this.completionRatio = 0,
    this.completionStatus = 'ongoing',
  });

  factory StudySession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return StudySession(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      studyBlockId: data['studyBlockId'] as String?,
      assignmentId: data['assignmentId'] as String?,
      goalId: data['goalId'] as String?,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      plannedDurationMinutes: data['plannedDurationMinutes'] as int? ?? 25,
      actualDurationMinutes: data['actualDurationMinutes'] as int? ?? 0,
      completionRatio: (data['completionRatio'] as num?)?.toDouble() ?? 0,
      completionStatus: data['completionStatus'] as String? ?? 'ongoing',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'studyBlockId': studyBlockId,
      'assignmentId': assignmentId,
      'goalId': goalId,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'plannedDurationMinutes': plannedDurationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
      'completionRatio': completionRatio,
      'completionStatus': completionStatus,
    };
  }
}
