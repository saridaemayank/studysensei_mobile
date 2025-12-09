import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalCategory { exam, subject, habit }

class LongTermGoal {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final GoalCategory category;
  final int priority;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LongTermGoal({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.targetDate,
  });

  factory LongTermGoal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final Timestamp? targetTimestamp = data['targetDate'] as Timestamp?;
    return LongTermGoal(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      category: _categoryFromString(data['category'] as String?),
      priority: data['priority'] is int ? data['priority'] as int : 0,
      targetDate: targetTimestamp?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'category': category.name,
      'priority': priority,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LongTermGoal copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    GoalCategory? category,
    int? priority,
    DateTime? targetDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LongTermGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static GoalCategory _categoryFromString(String? value) {
    switch (value) {
      case 'habit':
        return GoalCategory.habit;
      case 'subject':
        return GoalCategory.subject;
      case 'exam':
      default:
        return GoalCategory.exam;
    }
  }
}
