import 'package:cloud_firestore/cloud_firestore.dart';

class StudyBlock {
  final String id;
  final String userId;
  final String title;
  final String? subject;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? goalId;
  final String? assignmentId;
  final String? milestoneId;
  final bool reminderEnabled;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyBlock({
    required this.id,
    required this.userId,
    required this.title,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.subject,
    this.goalId,
    this.assignmentId,
    this.milestoneId,
    this.reminderEnabled = false,
    this.isCompleted = false,
  });

  factory StudyBlock.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return StudyBlock(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subject: data['subject'] as String?,
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: data['durationMinutes'] is int ? data['durationMinutes'] as int : 25,
      goalId: data['goalId'] as String?,
      assignmentId: data['assignmentId'] as String?,
      milestoneId: data['milestoneId'] as String?,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'subject': subject,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': durationMinutes,
      'goalId': goalId,
      'assignmentId': assignmentId,
      'milestoneId': milestoneId,
      'reminderEnabled': reminderEnabled,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  StudyBlock copyWith({
    String? id,
    String? userId,
    String? title,
    String? subject,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? goalId,
    String? assignmentId,
    String? milestoneId,
    bool? reminderEnabled,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyBlock(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      goalId: goalId ?? this.goalId,
      assignmentId: assignmentId ?? this.assignmentId,
      milestoneId: milestoneId ?? this.milestoneId,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
