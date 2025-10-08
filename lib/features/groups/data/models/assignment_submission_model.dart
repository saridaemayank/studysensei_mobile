import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/enums/submission_status.dart';

class AssignmentSubmission extends Equatable {
  final String id;
  final String assignmentId;
  final String userId;
  final String? content;
  final List<String>? attachmentUrls;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final String? feedback;
  final double? grade;

  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.userId,
    this.content,
    this.attachmentUrls,
    DateTime? submittedAt,
    this.status = SubmissionStatus.submitted,
    this.feedback,
    this.grade,
  }) : submittedAt = submittedAt ?? DateTime.now();

  // Convert model to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'userId': userId,
      'content': content,
      'attachmentUrls': attachmentUrls,
      'submittedAt': submittedAt,
      'status': status.toString(),
      'feedback': feedback,
      'grade': grade,
    };
  }

  // Helper method to parse status from string with null safety
  static SubmissionStatus _statusFromString(String? status) {
    if (status == null) return SubmissionStatus.submitted;
    
    // Remove the enum prefix if it exists
    final statusString = status.replaceAll('SubmissionStatus.', '');
    
    return SubmissionStatus.values.firstWhere(
      (e) => e.toString() == 'SubmissionStatus.$statusString' ||
             e.toString() == statusString,
      orElse: () => SubmissionStatus.submitted,
    );
  }

  // Create model from Firestore document
  factory AssignmentSubmission.fromMap(Map<String, dynamic> map) {
    try {
      // Ensure required fields exist and have valid values
      if (map['assignmentId'] == null || 
          map['userId'] == null) {
        throw FormatException('Missing required fields in submission data');
      }

      return AssignmentSubmission(
        id: (map['id'] as String?) ?? '',
        assignmentId: map['assignmentId'] as String,
        userId: map['userId'] as String,
        content: map['content'] as String?,
        attachmentUrls: map['attachmentUrls'] != null
            ? List<String>.from(map['attachmentUrls'] as List)
            : null,
        submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: _statusFromString(map['status']?.toString()),
        feedback: map['feedback'] as String?,
        grade: (map['grade'] as num?)?.toDouble(),
      );
    } catch (e, stackTrace) {
      print('Error parsing AssignmentSubmission: $e');
      print('Stack trace: $stackTrace');
      print('Problematic data: ${map.toString()}');
      rethrow;
    }
  }

  // Create a copy of the submission with some updated fields
  AssignmentSubmission copyWith({
    String? id,
    String? assignmentId,
    String? userId,
    String? content,
    List<String>? attachmentUrls,
    DateTime? submittedAt,
    SubmissionStatus? status,
    String? feedback,
    double? grade,
  }) {
    return AssignmentSubmission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      feedback: feedback ?? this.feedback,
      grade: grade ?? this.grade,
    );
  }

  @override
  List<Object?> get props => [
    id,
    assignmentId,
    userId,
    content,
    attachmentUrls,
    submittedAt,
    status,
    feedback,
    grade,
  ];

  bool get hasAttachments => attachmentUrls?.isNotEmpty ?? false;
  bool get isGraded => status == SubmissionStatus.graded;
  bool get needsRevision => status == SubmissionStatus.needsRevision;
  bool get isLate => status == SubmissionStatus.late;
}
