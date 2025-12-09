import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/home_assignment.dart';
import '../models/long_term_goal.dart';
import '../models/milestone.dart';
import '../models/study_block.dart';
import '../models/study_session.dart';

class HomeRepository {
  HomeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _milestoneCollectionName = 'milestones';

  CollectionReference<Map<String, dynamic>> _userGoals(String userId) {
    return _firestore.collection('users').doc(userId).collection('longTermGoals');
  }

  DocumentReference<Map<String, dynamic>> _milestoneDoc(
    String userId,
    String goalId,
    String milestoneId,
  ) {
    return _userGoals(userId)
        .doc(goalId)
        .collection(_milestoneCollectionName)
        .doc(milestoneId);
  }

  CollectionReference<Map<String, dynamic>> _userAssignments(String userId) {
    return _firestore.collection('users').doc(userId).collection('assignments');
  }

  CollectionReference<Map<String, dynamic>> _userStudyBlocks(String userId) {
    return _firestore.collection('users').doc(userId).collection('studyBlocks');
  }

  Stream<List<LongTermGoal>> watchGoals(String userId) {
    return _userGoals(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(LongTermGoal.fromDoc).toList());
  }

  Stream<List<Milestone>> watchMilestones(String userId) {
    return _firestore
        .collectionGroup(_milestoneCollectionName)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Milestone.fromDoc).toList());
  }

  Stream<List<HomeAssignment>> watchAssignments(String userId) {
    return _userAssignments(userId)
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(HomeAssignment.fromDoc).toList());
  }

  Stream<List<StudyBlock>> watchStudyBlocks(String userId) {
    return _userStudyBlocks(userId)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(StudyBlock.fromDoc).toList());
  }

  Stream<List<StudySession>> watchStudySessions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('studySessions')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(StudySession.fromDoc).toList());
  }

  CollectionReference<Map<String, dynamic>> _userStudySessions(String userId) {
    return _firestore.collection('users').doc(userId).collection('studySessions');
  }

  Future<void> toggleAssignmentCompletion({
    required String userId,
    required String assignmentId,
    required bool isCompleted,
  }) async {
    await _userAssignments(userId).doc(assignmentId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });

    if (isCompleted) {
      await _completeSessionsForAssignment(userId, assignmentId);
    }
  }

  Future<void> _completeSessionsForAssignment(String userId, String assignmentId) async {
    final sessions = await _userStudySessions(userId)
        .where('assignmentId', isEqualTo: assignmentId)
        .get();
    if (sessions.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in sessions.docs) {
      final data = doc.data();
      final status = data['completionStatus'] as String? ?? 'ongoing';
      if (status == 'completed') continue;
      final actualMinutes = (data['actualDurationMinutes'] as int?) ?? 0;
      final plannedMinutes = (data['plannedDurationMinutes'] as int?) ?? 0;
      batch.update(doc.reference, {
        'completionStatus': 'completed',
        'completionRatio': 1.0,
        'actualDurationMinutes': actualMinutes > 0 ? actualMinutes : plannedMinutes,
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> toggleMilestoneCompletion({
    required String userId,
    required String goalId,
    required String milestoneId,
    required bool isCompleted,
  }) {
    return _milestoneDoc(userId, goalId, milestoneId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<LongTermGoal> createGoal({
    required String userId,
    required String title,
    String? description,
    GoalCategory category = GoalCategory.exam,
    int priority = 1,
    DateTime? targetDate,
    List<Milestone> milestones = const [],
  }) async {
    final goalRef = _userGoals(userId).doc();
    final now = DateTime.now();
    final goal = LongTermGoal(
      id: goalRef.id,
      userId: userId,
      title: title,
      description: description,
      category: category,
      priority: priority,
      targetDate: targetDate,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(goalRef, goal.toMap());

    for (final milestone in milestones) {
      final docRef = goalRef.collection(_milestoneCollectionName).doc();
      batch.set(
        docRef,
        milestone
            .copyWith(
              id: docRef.id,
              goalId: goal.id,
              userId: userId,
            )
            .toMap(),
      );
    }

    await batch.commit();
    return goal;
  }

  Future<Milestone> addMilestone({
    required String userId,
    required String goalId,
    required String title,
    DateTime? dueDate,
    Map<String, dynamic>? metadata,
  }) async {
    final milestoneRef =
        _userGoals(userId).doc(goalId).collection(_milestoneCollectionName).doc();
    final milestone = Milestone(
      id: milestoneRef.id,
      goalId: goalId,
      userId: userId,
      title: title,
      dueDate: dueDate,
    );
    final data = milestone.toMap();
    if (metadata != null) {
      data.addAll(metadata);
    }
    await milestoneRef.set(data);
    return milestone;
  }

  Future<void> appendLinkedAssignmentToMilestone({
    required String userId,
    required String goalId,
    required String milestoneId,
    required String assignmentId,
  }) {
    return _milestoneDoc(userId, goalId, milestoneId).update({
      'linkedAssignmentIds': FieldValue.arrayUnion([assignmentId]),
    });
  }

  Future<void> appendLinkedSessionToMilestone({
    required String userId,
    required String goalId,
    required String milestoneId,
    required String sessionId,
  }) {
    return _milestoneDoc(userId, goalId, milestoneId).update({
      'linkedSessionIds': FieldValue.arrayUnion([sessionId]),
    });
  }

  Future<void> deleteGoal({
    required String userId,
    required String goalId,
  }) async {
    final goalRef = _userGoals(userId).doc(goalId);
    final milestonesSnapshot =
        await goalRef.collection(_milestoneCollectionName).get();
    final batch = _firestore.batch();
    for (final doc in milestonesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(goalRef);
    await batch.commit();
  }

  Future<StudyBlock> createStudyBlock({
    required String userId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? subject,
    String? goalId,
    String? assignmentId,
    String? milestoneId,
    bool reminderEnabled = false,
  }) async {
    final docRef = _userStudyBlocks(userId).doc();
    final now = DateTime.now();
    final block = StudyBlock(
      id: docRef.id,
      userId: userId,
      title: title,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      subject: subject,
      goalId: goalId,
      assignmentId: assignmentId,
      milestoneId: milestoneId,
      reminderEnabled: reminderEnabled,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(block.toMap());
    return block;
  }

  Future<void> updateStudyBlock({
    required String userId,
    required String blockId,
    required Map<String, dynamic> data,
  }) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _userStudyBlocks(userId).doc(blockId).update(data);
  }

  Future<void> deleteStudyBlock({
    required String userId,
    required String blockId,
  }) {
    return _userStudyBlocks(userId).doc(blockId).delete();
  }
}
