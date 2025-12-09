import 'package:cloud_firestore/cloud_firestore.dart';

class HomeAssignment {
  final String id;
  final String userId;
  final String title;
  final String subject;
  final DateTime deadline;
  final bool isCompleted;
  final int? estimatedMinutes;
  final String? goalId;
  final String? milestoneId;

  const HomeAssignment({
    required this.id,
    required this.userId,
    required this.title,
    required this.subject,
    required this.deadline,
    required this.isCompleted,
    this.estimatedMinutes,
    this.goalId,
    this.milestoneId,
  });

  factory HomeAssignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final Timestamp? deadlineStamp = data['deadline'] as Timestamp?;
    return HomeAssignment(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: (data['title'] ?? data['name']) as String? ?? '',
      subject: data['subject'] as String? ?? 'General',
      deadline: deadlineStamp?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? data['completed'] as bool? ?? false,
      estimatedMinutes: data['estimatedMinutes'] as int?,
      goalId: data['goalId'] as String?,
      milestoneId: data['milestoneId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'subject': subject,
      'deadline': Timestamp.fromDate(deadline),
      'isCompleted': isCompleted,
      'estimatedMinutes': estimatedMinutes,
      'goalId': goalId,
      'milestoneId': milestoneId,
    };
  }

  HomeAssignment copyWith({
    String? id,
    String? userId,
    String? title,
    String? subject,
    DateTime? deadline,
    bool? isCompleted,
    int? estimatedMinutes,
    String? goalId,
    String? milestoneId,
  }) {
    return HomeAssignment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      goalId: goalId ?? this.goalId,
      milestoneId: milestoneId ?? this.milestoneId,
    );
  }
}
