import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_sensei/core/error/exceptions.dart';
import 'package:study_sensei/features/groups/data/models/assignment_submission_model.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

class GroupRemoteDataSource {
  final FirebaseFirestore _firestore;

  GroupRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _groupsCollection => _firestore.collection('groups');
  CollectionReference get _assignmentsCollection =>
      _firestore.collection('group_assignments');

  // Group operations
  Stream<List<Group>> getUserGroups(String userId) {
    try {
      return _groupsCollection
          .where('memberIds', arrayContains: userId)
          .snapshots()
          .handleError((error) {
        throw ServerException('Failed to fetch user groups: $error');
      }).map((snapshot) => snapshot.docs
          .map((doc) => Group.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList());
    } catch (e) {
      throw ServerException('Failed to fetch user groups: $e');
    }
  }

  Future<Group> getGroup(String groupId) async {
    try {
      final doc = await _groupsCollection.doc(groupId).get();
      if (!doc.exists) {
        throw NotFoundException('Group not found');
      }
      return Group.fromMap(doc.id, doc.data()! as Map<String, dynamic>);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to fetch group: $e');
    }
  }

  Future<Group> createGroup(Group group) async {
    try {
      final docRef = await _groupsCollection.add(group.toMap());
      return group.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to create group: $e');
    }
  }

  Future<void> updateGroup(Group group) async {
    try {
      await _groupsCollection.doc(group.id).update(group.toMap());
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to update group: $e');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _groupsCollection.doc(groupId).delete();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to delete group: $e');
    }
  }

  // Group member operations
  Future<void> addGroupMember(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'pendingInvites': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to add group member: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to add group member: $e');
    }
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'adminIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to remove member from group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to remove member from group: $e');
    }
  }

  Future<void> addGroupAdmin(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'adminIds': FieldValue.arrayUnion([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to add admin to group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to add admin to group: $e');
    }
  }

  Future<void> removeGroupAdmin(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'adminIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to remove admin from group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to remove admin from group: $e');
    }
  }

  Future<void> inviteToGroup(String groupId, String email) async {
    try {
      // In a real app, you would send an email invitation here
      // For now, we'll just add the email to pending invites
      await _groupsCollection.doc(groupId).update({
        'pendingInvites': FieldValue.arrayUnion([email]),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to invite user to group: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to invite user to group: $e');
    }
  }

  Future<void> cancelInvite(String groupId, String email) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'pendingInvites': FieldValue.arrayRemove([email]),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to cancel invite: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to cancel invite: $e');
    }
  }

  // Assignment operations
  Stream<List<GroupAssignment>> getGroupAssignments(String groupId) {
    try {
      return _assignmentsCollection
          .where('groupId', isEqualTo: groupId)
          .orderBy('dueDate', descending: false)
          .snapshots()
          .handleError((error) {
        throw ServerException('Failed to fetch group assignments: $error');
      }).map((snapshot) => snapshot.docs
          .map((doc) => GroupAssignment.fromMap(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList());
    } catch (e) {
      throw ServerException('Failed to fetch group assignments: $e');
    }
  }

  Future<GroupAssignment> getAssignment(String assignmentId) async {
    try {
      final doc = await _assignmentsCollection.doc(assignmentId).get();
      if (!doc.exists) {
        throw NotFoundException('Assignment not found');
      }
      return GroupAssignment.fromMap(
          doc.id, doc.data() as Map<String, dynamic>);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch assignment: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to fetch assignment: $e');
    }
  }

  Future<GroupAssignment> createAssignment(GroupAssignment assignment) async {
    try {
      final docRef = await _assignmentsCollection.add(assignment.toMap());
      return assignment.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create assignment: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to create assignment: $e');
    }
  }

  Future<void> updateAssignment(GroupAssignment assignment) async {
    try {
      await _assignmentsCollection
          .doc(assignment.id)
          .update(assignment.toMap()..['updatedAt'] = DateTime.now());
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update assignment: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to update assignment: $e');
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    try {
      await _assignmentsCollection.doc(assignmentId).delete();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete assignment: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to delete assignment: $e');
    }
  }

  // Submission operations
  Future<void> submitAssignment(AssignmentSubmission submission) async {
    try {
      final assignmentDoc = _assignmentsCollection.doc(submission.assignmentId);
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(assignmentDoc);
        if (!doc.exists) {
          throw NotFoundException('Assignment not found');
        }

        final data = doc.data() as Map<String, dynamic>;
        final submissions = List<Map<String, dynamic>>.from(
          (data['submissions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        );

        // Remove existing submission if it exists
        submissions.removeWhere((s) => s['userId'] == submission.userId);

        // Add new submission
        submissions.add(submission.toMap());

        // Update the assignment
        transaction.update(assignmentDoc, {
          'submissions': submissions,
          'updatedAt': DateTime.now(),
        });
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to submit assignment: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to submit assignment: $e');
    }
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    try {
      // This is a simplified implementation
      // In a real app, you would need to find the assignment containing this submission
      // and update the specific submission's grade and feedback
      throw UnimplementedError('grading submissions is not yet implemented');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to grade submission: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to grade submission: $e');
    }
  }

  // Search operations
  Stream<List<Group>> searchGroups(String query) {
    try {
      if (query.isEmpty) {
        return _groupsCollection
            .where('isPublic', isEqualTo: true)
            .limit(50)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => Group.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                .toList());
      }
      
      final searchTerm = query.toLowerCase();
      return _groupsCollection
          .where('isPublic', isEqualTo: true)
          .where('searchTerms', arrayContains: searchTerm)
          .limit(50)
          .snapshots()
          .handleError((error) {
            throw ServerException('Failed to search groups: $error');
          })
          .map((snapshot) => snapshot.docs
              .map((doc) => Group.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList());
    } on FirebaseException catch (e) {
      throw ServerException('Failed to search groups: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to search groups: $e');
    }
  }

  Future<List<Group>> getPublicGroups() async {
    try {
      final snapshot = await _groupsCollection
          .where('isPublic', isEqualTo: true)
          .limit(50)
          .get();
      
      return snapshot.docs
          .map((doc) => Group.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get public groups: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to get public groups: $e');
    }
  }
}
