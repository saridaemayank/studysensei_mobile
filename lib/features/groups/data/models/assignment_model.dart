class Assignment {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String createdBy;
  final DateTime createdAt;
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    this.dueDate,
    required this.createdBy,
    DateTime? createdAt,
    this.isCompleted = false,
    this.completedBy,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'completedBy': completedBy,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      isCompleted: json['isCompleted'] ?? false,
      completedBy: json['completedBy'],
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }

  Assignment copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? createdBy,
    DateTime? createdAt,
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
