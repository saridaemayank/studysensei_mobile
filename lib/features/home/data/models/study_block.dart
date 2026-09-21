import 'package:cloud_firestore/cloud_firestore.dart';

class StudyBlock {
  final String id;
  final String userId;
  final String title;
  final String? subject;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? dojoId;
  final String? chapterId;
  final String? blockType;
  final String? notes;
  final String? roadmapRef;
  final String? status;
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
    this.dojoId,
    this.chapterId,
    this.blockType,
    this.notes,
    this.roadmapRef,
    this.status,
    this.goalId,
    this.assignmentId,
    this.milestoneId,
    this.reminderEnabled = false,
    this.isCompleted = false,
  });

  factory StudyBlock.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime resolveDate() {
      final scheduledTs = (data['scheduledAt'] as Timestamp?)?.toDate();
      if (scheduledTs != null) return scheduledTs;
      final sessionTs = (data['sessionDate'] as Timestamp?)?.toDate();
      if (sessionTs != null) return sessionTs;
      final dateString = data['date'] as String?;
      if (dateString != null) {
        final segments = dateString.split('-').map(int.tryParse).toList();
        if (segments.length == 3 &&
            segments[0] != null &&
            segments[1] != null &&
            segments[2] != null) {
          return DateTime(
            segments[0]!,
            segments[1]!,
            segments[2]!,
          );
        }
      }
      return DateTime.now();
    }

    final blockType = data['blockType'] as String? ?? data['type'] as String?;
    final title = data['title'] as String? ??
        data['chapter'] as String? ??
        data['chapterName'] as String? ??
        (blockType != null ? '$blockType block' : 'Study block');
    final subjectName =
        data['subject'] as String? ?? data['subjectName'] as String?;
    final status = data['status'] as String?;
    return StudyBlock(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: title,
      subject: subjectName,
      dojoId: data['dojoId'] as String?,
      chapterId: data['chapterId'] as String?,
      blockType: blockType,
      notes: data['notes'] as String?,
      roadmapRef: data['roadmapRef'] as String?,
      status: status,
      scheduledAt: resolveDate(),
      durationMinutes:
          data['durationMinutes'] is int ? data['durationMinutes'] as int : 25,
      goalId: data['goalId'] as String?,
      assignmentId: data['assignmentId'] as String?,
      milestoneId: data['milestoneId'] as String?,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      isCompleted: data['isCompleted'] as bool? ??
          (status != null && status.toLowerCase() == 'completed'),
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
      'dojoId': dojoId,
      'chapterId': chapterId,
      'blockType': blockType,
      'notes': notes,
      'roadmapRef': roadmapRef,
      'status': status,
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
    String? dojoId,
    String? chapterId,
    String? blockType,
    String? notes,
    String? roadmapRef,
    String? status,
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
      dojoId: dojoId ?? this.dojoId,
      chapterId: chapterId ?? this.chapterId,
      blockType: blockType ?? this.blockType,
      notes: notes ?? this.notes,
      roadmapRef: roadmapRef ?? this.roadmapRef,
      status: status ?? this.status,
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
