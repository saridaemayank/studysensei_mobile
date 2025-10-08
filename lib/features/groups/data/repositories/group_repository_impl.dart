import 'package:dartz/dartz.dart';
import 'package:study_sensei/core/error/failures.dart';
import 'package:study_sensei/core/error/exceptions.dart';
import 'package:study_sensei/features/groups/data/datasources/group_remote_data_source.dart';
import 'package:study_sensei/features/groups/domain/repositories/group_repository.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';
import 'package:study_sensei/features/groups/data/models/assignment_submission_model.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;

  GroupRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<Group>> getUserGroups(String userId) {
    try {
      return remoteDataSource.getUserGroups(userId);
    } catch (e) {
      // Return an empty stream in case of error
      return Stream.value([]);
    }
  }

  @override
  Future<Either<Failure, Group>> getGroup(String groupId) async {
    try {
      final group = await remoteDataSource.getGroup(groupId);
      return Right(group);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Group>> createGroup(Group group) async {
    try {
      final createdGroup = await remoteDataSource.createGroup(group);
      return Right(createdGroup);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateGroup(Group group) async {
    try {
      await remoteDataSource.updateGroup(group);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGroup(String groupId) async {
    try {
      await remoteDataSource.deleteGroup(groupId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addGroupMember(
      String groupId, String userId) async {
    try {
      await remoteDataSource.addGroupMember(groupId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeGroupMember(
      String groupId, String userId) async {
    try {
      await remoteDataSource.removeGroupMember(groupId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addGroupAdmin(
      String groupId, String userId) async {
    try {
      await remoteDataSource.addGroupAdmin(groupId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeGroupAdmin(
      String groupId, String userId) async {
    try {
      await remoteDataSource.removeGroupAdmin(groupId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> inviteToGroup(
      String groupId, String email) async {
    try {
      await remoteDataSource.inviteToGroup(groupId, email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> cancelInvite(
      String groupId, String email) async {
    try {
      await remoteDataSource.cancelInvite(groupId, email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Stream<List<GroupAssignment>> getGroupAssignments(String groupId) {
    try {
      return remoteDataSource.getGroupAssignments(groupId);
    } catch (e) {
      // Return an empty stream in case of error
      return Stream.value([]);
    }
  }

  @override
  Future<Either<Failure, GroupAssignment>> getAssignment(
      String assignmentId) async {
    try {
      final assignment = await remoteDataSource.getAssignment(assignmentId);
      return Right(assignment);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, GroupAssignment>> createAssignment(
      GroupAssignment assignment) async {
    try {
      final createdAssignment =
          await remoteDataSource.createAssignment(assignment);
      return Right(createdAssignment);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateAssignment(
      GroupAssignment assignment) async {
    try {
      await remoteDataSource.updateAssignment(assignment);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAssignment(String assignmentId) async {
    try {
      await remoteDataSource.deleteAssignment(assignmentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> submitAssignment(
      AssignmentSubmission submission) async {
    try {
      await remoteDataSource.submitAssignment(submission);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    try {
      await remoteDataSource.gradeSubmission(
        submissionId: submissionId,
        grade: grade,
        feedback: feedback,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Stream<List<Group>> searchGroups(String query) {
    try {
      return remoteDataSource.searchGroups(query);
    } catch (e) {
      // Return an empty stream in case of error
      return Stream.value([]);
    }
  }

  @override
  Future<Either<Failure, List<Group>>> getPublicGroups() async {
    try {
      final groups = await remoteDataSource.getPublicGroups();
      return Right(groups);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
