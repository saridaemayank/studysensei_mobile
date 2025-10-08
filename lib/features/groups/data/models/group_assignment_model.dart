import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/enums/assignment_status.dart';
import 'package:study_sensei/features/groups/data/models/assignment_submission_model.dart';

class GroupAssignment extends Equatable {
  final String id;
  final String groupId;
  final String title;
  final String description;
  final String createdBy;
  final DateTime dueDate;
  final AssignmentStatus status;
  final List<String> assignedTo;
  final List<AssignmentSubmission> submissions;
  final Map<String, bool> userCompletion; // userId -> isCompleted
  final DateTime createdAt;
  final DateTime? updatedAt;

  GroupAssignment({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.dueDate,
    this.status = AssignmentStatus.notStarted,
    List<String>? assignedTo,
    List<AssignmentSubmission>? submissions,
    Map<String, bool>? userCompletion,
    DateTime? createdAt,
    this.updatedAt,
  }) : assignedTo = assignedTo ?? [],
       submissions = submissions ?? [],
       userCompletion = userCompletion ?? {},
       createdAt = createdAt ?? DateTime.now();
       
  bool isCompletedByUser(String userId) => userCompletion[userId] ?? false;
  
  GroupAssignment copyWithUserCompletion(String userId, bool isCompleted) {
    // Create an updated user completion map
    final updatedUserCompletion = Map<String, bool>.from(userCompletion)..[userId] = isCompleted;
    
    // Determine the new status
    AssignmentStatus newStatus = status;
    if (assignedTo.isNotEmpty) {
      final allCompleted = assignedTo.every((uid) => updatedUserCompletion[uid] == true);
      final someCompleted = assignedTo.any((uid) => updatedUserCompletion[uid] == true);
      
      if (allCompleted) {
        newStatus = AssignmentStatus.completed;
      } else if (someCompleted) {
        newStatus = AssignmentStatus.inProgress;
      } else {
        newStatus = AssignmentStatus.notStarted;
      }
    }
    
    return GroupAssignment(
      id: id,
      groupId: groupId,
      title: title,
      description: description,
      createdBy: createdBy,
      dueDate: dueDate,
      status: newStatus,
      assignedTo: List.from(assignedTo),
      submissions: List.from(submissions),
      userCompletion: updatedUserCompletion,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert model to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'dueDate': dueDate,
      'status': status.toString(),
      'assignedTo': assignedTo,
      'submissions': submissions.map((s) => s.toMap()).toList(),
      'userCompletion': userCompletion,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Helper method to parse status from string with null safety
  static AssignmentStatus _statusFromString(String? status) {
    if (status == null) return AssignmentStatus.notStarted;
    
    // Remove the enum prefix if it exists
    String statusString = status;
    if (status.startsWith('AssignmentStatus.')) {
      statusString = status.replaceAll('AssignmentStatus.', '');
    }
    
    // Try to match the status (case-insensitive)
    for (var value in AssignmentStatus.values) {
      if (value.toString().toLowerCase() == 'AssignmentStatus.${statusString.toLowerCase()}' ||
          value.name.toLowerCase() == statusString.toLowerCase()) {
        return value;
      }
    }
    
    return AssignmentStatus.notStarted;
  }

  // Create model from Firestore document
  factory GroupAssignment.fromMap(String id, Map<String, dynamic> map) {
    try {
      // Provide default values for required fields
      final groupId = map['groupId'] as String? ?? '';
      final title = map['title'] as String? ?? 'Untitled Assignment';
      final description = map['description'] as String? ?? '';
      final createdBy = map['createdBy'] as String? ?? '';
      
      // Debug log the status value from Firestore
      final statusValue = map['status']?.toString() ?? 'notStarted';
      print('Parsing status from Firestore. Raw value: $statusValue');
      final status = _statusFromString(statusValue);
      print('Parsed status: $status (${status.name})');
      final dueDate = map['dueDate'] != null 
          ? (map['dueDate'] is Timestamp 
              ? (map['dueDate'] as Timestamp).toDate() 
              : DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now().add(const Duration(days: 7)))
          : DateTime.now().add(const Duration(days: 7));

      return GroupAssignment(
        id: id,
        groupId: groupId,
        title: title,
        description: description,
        createdBy: createdBy,
        dueDate: dueDate,
        status: status,
        assignedTo: map['assignedTo'] != null 
            ? List<String>.from(map['assignedTo'] as List)
            : [],
        submissions: (map['submissions'] as List<dynamic>?)
            ?.map<AssignmentSubmission>((s) => 
                AssignmentSubmission.fromMap(s as Map<String, dynamic>))
            .toList() ?? [],
        userCompletion: map['userCompletion'] != null 
            ? Map<String, bool>.from(map['userCompletion'] as Map)
            : {},
        createdAt: map['createdAt'] != null 
            ? (map['createdAt'] is Timestamp
                ? (map['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null 
            ? (map['updatedAt'] is Timestamp
                ? (map['updatedAt'] as Timestamp).toDate()
                : DateTime.tryParse(map['updatedAt'].toString()))
            : null,
      );
    } catch (e, stackTrace) {
      print('Error parsing GroupAssignment: $e');
      print('Stack trace: $stackTrace');
      print('Problematic data: ${map.toString()}');
      // Instead of rethrowing, return a default valid assignment
      return GroupAssignment(
        id: id,
        groupId: '',
        title: 'Error Loading Assignment',
        description: 'There was an error loading this assignment',
        createdBy: 'system',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        status: AssignmentStatus.notStarted,
      );
    }
  }

  // Create a copy of the assignment with some updated fields
  GroupAssignment copyWith({
    String? id,
    String? groupId,
    String? title,
    String? description,
    String? createdBy,
    DateTime? dueDate,
    AssignmentStatus? status,
    List<String>? assignedTo,
    List<AssignmentSubmission>? submissions,
    Map<String, bool>? userCompletion,
    DateTime? updatedAt,
  }) {
    return GroupAssignment(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      assignedTo: assignedTo ?? List.from(this.assignedTo),
      submissions: submissions ?? List.from(this.submissions),
      userCompletion: userCompletion ?? Map.from(this.userCompletion),
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        title,
        description,
        createdBy,
        dueDate,
        status,
        assignedTo,
        submissions,
        userCompletion,
        createdAt,
        updatedAt,
      ];

  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) &&
      status != AssignmentStatus.completed &&
      status != AssignmentStatus.graded;

  int get submissionCount => submissions.length;
  bool get hasSubmissions => submissions.isNotEmpty;
}
