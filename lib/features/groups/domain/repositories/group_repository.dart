import 'package:dartz/dartz.dart';
import 'package:study_sensei/core/error/failures.dart';
import 'package:study_sensei/features/groups/data/models/assignment_submission_model.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';

abstract class GroupRepository {
  // Group operations
  Stream<List<Group>> getUserGroups(String userId);
  Future<Either<Failure, Group>> getGroup(String groupId);
  Future<Either<Failure, Group>> createGroup(Group group);
  Future<Either<Failure, void>> updateGroup(Group group);
  Future<Either<Failure, void>> deleteGroup(String groupId);

  // Group member operations
  Future<Either<Failure, void>> addGroupMember(String groupId, String userId);
  Future<Either<Failure, void>> removeGroupMember(
    String groupId,
    String userId,
  );
  Future<Either<Failure, void>> addGroupAdmin(String groupId, String userId);
  Future<Either<Failure, void>> removeGroupAdmin(String groupId, String userId);
  Future<Either<Failure, void>> inviteToGroup(String groupId, String email);
  Future<Either<Failure, void>> cancelInvite(String groupId, String email);

  // Assignment operations
  Stream<List<GroupAssignment>> getGroupAssignments(String groupId);
  Future<Either<Failure, GroupAssignment>> getAssignment(String assignmentId);
  Future<Either<Failure, GroupAssignment>> createAssignment(
    GroupAssignment assignment,
  );
  Future<Either<Failure, void>> updateAssignment(GroupAssignment assignment);
  Future<Either<Failure, void>> deleteAssignment(String assignmentId);

  // Submission operations
  Future<Either<Failure, void>> submitAssignment(
    AssignmentSubmission submission,
  );
  Future<Either<Failure, void>> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  });

  // Search operations
  Stream<List<Group>> searchGroups(String query);
  Future<Either<Failure, List<Group>>> getPublicGroups();
}
