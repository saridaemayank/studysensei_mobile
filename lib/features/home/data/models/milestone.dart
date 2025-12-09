import 'package:cloud_firestore/cloud_firestore.dart';

class Milestone {
  final String id;
  final String goalId;
  final String userId;
  final String title;
  final DateTime? dueDate;
  final bool isCompleted;
  final List<String> linkedAssignmentIds;
  final List<String> linkedSessionIds;

  const Milestone({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.title,
    this.dueDate,
    this.isCompleted = false,
    this.linkedAssignmentIds = const [],
    this.linkedSessionIds = const [],
  });

  factory Milestone.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Milestone(
      id: doc.id,
      goalId: data['goalId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      linkedAssignmentIds: _parseIdList(
            data['linkedAssignmentIds'],
          ) ??
          _fallbackSingleId(data['linkedAssignmentId']) ??
          const [],
      linkedSessionIds: _parseIdList(
            data['linkedSessionIds'],
          ) ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'userId': userId,
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isCompleted': isCompleted,
      'linkedAssignmentIds': linkedAssignmentIds,
      'linkedSessionIds': linkedSessionIds,
    };
  }

  Milestone copyWith({
    String? id,
    String? goalId,
    String? userId,
    String? title,
    DateTime? dueDate,
    bool? isCompleted,
    List<String>? linkedAssignmentIds,
    List<String>? linkedSessionIds,
  }) {
    return Milestone(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedAssignmentIds: linkedAssignmentIds ?? this.linkedAssignmentIds,
      linkedSessionIds: linkedSessionIds ?? this.linkedSessionIds,
    );
  }
}

List<String>? _parseIdList(dynamic raw) {
  if (raw == null) return null;
  if (raw is List<dynamic>) {
    return raw.whereType<String>().toList();
  }
  return null;
}

List<String>? _fallbackSingleId(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return [raw];
  }
  return null;
}
