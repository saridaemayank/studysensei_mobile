import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exam_dojo_group.dart';
import '../models/exam_dojo_daily_block.dart';
import '../models/exam_dojo_subject.dart';
import '../models/exam_dojo_progress_summary.dart';
import '../../services/exam_dojo_api_service.dart';
import '../../services/exam_dojo_logger.dart';

class ExamDojoRepository {
  ExamDojoRepository({
    FirebaseFirestore? firestore,
    ExamDojoApiService? apiService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _apiService = apiService ?? ExamDojoApiService();

  final FirebaseFirestore _firestore;
  final ExamDojoApiService _apiService;

  Stream<ExamDojoGroup?> streamActiveDojo(String userId) async* {
    final userDocRef = _firestore.collection('users').doc(userId);
    ExamDojoLogger.log(
      'repository.streamActiveDojo.listen',
      details: {'userId': userId},
    );

    await for (final userSnapshot in userDocRef.snapshots()) {
      final data = userSnapshot.data();
      final activeId = data?['activeExamDojoId']?.toString();
      if (activeId == null || activeId.isEmpty) {
        ExamDojoLogger.log(
          'repository.streamActiveDojo.noActiveId',
          details: {'userId': userId},
        );
        ExamDojoGroup? fallback;
        try {
          fallback = await _findFirstDojoForUser(userId, userDocRef);
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            ExamDojoLogger.log(
              'repository.streamActiveDojo.memberLookupDenied',
              details: {'userId': userId},
            );
            yield null;
            continue;
          }
          rethrow;
        }
        if (fallback != null) {
          ExamDojoLogger.log(
            'repository.streamActiveDojo.fallbackApplied',
            details: {'userId': userId, 'dojoId': fallback.id},
          );
          yield fallback;
        } else {
          ExamDojoLogger.log(
            'repository.streamActiveDojo.noMembership',
            details: {'userId': userId},
          );
          yield null;
        }
        continue;
      }

      DocumentSnapshot<Map<String, dynamic>> dojoSnapshot;
      try {
        ExamDojoLogger.log(
          'repository.streamActiveDojo.fetch',
          details: {'userId': userId, 'dojoId': activeId},
        );
        dojoSnapshot =
            await _firestore.collection('exam_dojos').doc(activeId).get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          ExamDojoLogger.log(
            'repository.streamActiveDojo.permissionDenied',
            details: {'userId': userId, 'dojoId': activeId},
          );
          await _clearActiveDojo(userDocRef);
          yield null;
          continue;
        }
        rethrow;
      }
      if (!dojoSnapshot.exists || dojoSnapshot.data() == null) {
        ExamDojoLogger.log(
          'repository.streamActiveDojo.missingDoc',
          details: {'userId': userId, 'dojoId': activeId},
        );
        await _clearActiveDojo(userDocRef);
        try {
          final recovered = await _findFirstDojoForUser(userId, userDocRef);
          if (recovered != null) {
            ExamDojoLogger.log(
              'repository.streamActiveDojo.recovered',
              details: {'userId': userId, 'dojoId': recovered.id},
            );
            yield recovered;
          } else {
            yield null;
          }
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            ExamDojoLogger.log(
              'repository.streamActiveDojo.recoverDenied',
              details: {'userId': userId},
            );
            yield null;
          } else {
            rethrow;
          }
        }
        continue;
      }

      ExamDojoLogger.log(
        'repository.streamActiveDojo.emit',
        details: {'userId': userId, 'dojoId': activeId},
      );
      yield ExamDojoGroup.fromMap(activeId, dojoSnapshot.data()!);
    }
  }

  Future<ExamDojoGroup?> _findFirstDojoForUser(
    String userId,
    DocumentReference<Map<String, dynamic>> userDocRef,
  ) async {
    ExamDojoLogger.log(
      'repository.findFirstDojo.start',
      details: {'userId': userId},
    );
    final query = await _firestore
        .collection('exam_dojos')
        .where('memberIds', arrayContains: userId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data();
      final adminIds = (data['adminIds'] as List?)
              ?.where((id) => id != null)
              .map((id) => id.toString())
              .toList() ??
          const <String>[];
      final isAdmin = adminIds.contains(userId);
      await userDocRef.set(
        {
          'activeExamDojoId': doc.id,
          'activeExamDojoRole': isAdmin ? 'admin' : 'member',
        },
        SetOptions(merge: true),
      );
      ExamDojoLogger.log(
        'repository.findFirstDojo.activate',
        details: {
          'userId': userId,
          'dojoId': doc.id,
          'role': isAdmin ? 'admin' : 'member',
          'source': 'exam_dojos.memberIds',
        },
      );
      return ExamDojoGroup.fromMap(doc.id, data);
    }

    final membersCollection = _firestore.collectionGroup('members');
    QuerySnapshot<Map<String, dynamic>> memberQuery = await membersCollection
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (memberQuery.docs.isEmpty) {
      memberQuery = await membersCollection
          .where(FieldPath.documentId, isEqualTo: userId)
          .limit(1)
          .get();
    }
    if (memberQuery.docs.isEmpty) {
      ExamDojoLogger.log(
        'repository.findFirstDojo.noMemberDoc',
        details: {'userId': userId},
      );
      return null;
    }

    final memberDoc = memberQuery.docs.first;
    final dojoRef = memberDoc.reference.parent.parent;
    if (dojoRef == null) return null;

    final memberData = memberDoc.data();
    final isAdmin = memberData['isAdmin'] == true;
    await userDocRef.set(
      {
        'activeExamDojoId': dojoRef.id,
        'activeExamDojoRole': isAdmin ? 'admin' : 'member',
      },
      SetOptions(merge: true),
    );
    ExamDojoLogger.log(
      'repository.findFirstDojo.activate',
      details: {
        'userId': userId,
        'dojoId': dojoRef.id,
        'role': isAdmin ? 'admin' : 'member',
        'source': 'membersCollection',
      },
    );

    final dojoSnapshot = await dojoRef.get();
    if (!dojoSnapshot.exists || dojoSnapshot.data() == null) {
      ExamDojoLogger.log(
        'repository.findFirstDojo.noSnapshot',
        details: {'userId': userId, 'dojoId': dojoRef.id},
      );
      return null;
    }
    return ExamDojoGroup.fromMap(dojoRef.id, dojoSnapshot.data()!);
  }

  Future<void> _clearActiveDojo(
    DocumentReference<Map<String, dynamic>> userDocRef,
  ) async {
    await userDocRef.set(
      {
        'activeExamDojoId': FieldValue.delete(),
        'activeExamDojoRole': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }

  Future<ExamDojoGroup> createDojo({
    required String userId,
    required String name,
    String? description,
    required List<ExamDojoSubject> subjects,
    List<String>? memberIds,
  }) async {
    final members = {...?memberIds, userId}.toList();
    ExamDojoLogger.log(
      'repository.createDojo.start',
      details: {
        'userId': userId,
        'name': name,
        'memberIds': members,
        'subjects': subjects
            .map(
              (subject) => {
                'id': subject.id,
                'name': subject.name,
                'chapters': subject.chapters,
              },
            )
            .toList(),
      },
    );
    final response = await _apiService.createDojo(
      name: name,
      description: description,
      timezone: _resolveTimezone(),
      memberIds: members,
      subjects: subjects,
    );

    final dojoPayload = (response['dojo'] as Map<String, dynamic>?) ?? response;
    final dojoId = dojoPayload['id']?.toString() ??
        dojoPayload['dojoId']?.toString() ??
        dojoPayload['uid']?.toString();
    if (dojoId == null || dojoId.isEmpty) {
      throw Exception('Exam Dojo API did not return an id.');
    }
    ExamDojoLogger.log(
      'repository.createDojo.success',
      details: {
        'dojoId': dojoId,
        'subjectCount': subjects.length,
      },
    );

    await _firestore.collection('users').doc(userId).set(
      {
        'activeExamDojoId': dojoId,
        'activeExamDojoRole': 'admin',
      },
      SetOptions(merge: true),
    );

    return ExamDojoGroup.fromMap(dojoId, dojoPayload);
  }

  Future<List<ExamDojoDailyBlock>> generateDailyBlocks({
    required String dojoId,
    required DateTime date,
  }) async {
    final timezone = _resolveTimezone();
    ExamDojoLogger.log(
      'repository.generateDailyBlocks.request',
      details: {
        'dojoId': dojoId,
        'date': date.toIso8601String(),
      },
    );
    final rawBlocks = await _apiService.generateDailyBlocks(
      dojoId: dojoId,
      date: date,
      timezone: timezone,
    );
    final mapped = rawBlocks.map(ExamDojoDailyBlock.fromMap).toList();
    ExamDojoLogger.log(
      'repository.generateDailyBlocks.response',
      details: {
        'dojoId': dojoId,
        'blockCount': mapped.length,
      },
    );
    return mapped;
  }

  Future<List<ExamDojoDailyBlock>> fetchStoredBlocks({
    required String userId,
    required String dojoId,
    required DateTime date,
  }) async {
    final dateKey = _formatDateOnly(date);
    ExamDojoLogger.log(
      'repository.fetchStoredBlocks.request',
      details: {'userId': userId, 'dojoId': dojoId, 'date': dateKey},
    );
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('studyBlocks')
        .where('dojoId', isEqualTo: dojoId)
        .where('date', isEqualTo: dateKey)
        .get();
    final Map<String, ExamDojoDailyBlock> deduped = {};
    for (final doc in snapshot.docs) {
      final block = ExamDojoDailyBlock.fromMap({
        'id': doc.id,
        ...doc.data(),
      });
      final identity = _blockIdentity(block);
      final existing = deduped[identity];
      if (existing == null) {
        deduped[identity] = block;
        continue;
      }
      if (_shouldReplaceStoredBlock(
        preferredKey: identity,
        current: existing,
        candidate: block,
      )) {
        deduped[identity] = block;
      }
    }
    final blocks = deduped.values.toList()
      ..sort((a, b) {
        DateTime fallback(String date) =>
            DateTime.tryParse('${date}T00:00:00') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final left = a.sessionDate ?? fallback(a.date);
        final right = b.sessionDate ?? fallback(b.date);
        return left.compareTo(right);
      });
    ExamDojoLogger.log(
      'repository.fetchStoredBlocks.response',
      details: {
        'userId': userId,
        'dojoId': dojoId,
        'date': dateKey,
        'blockCount': blocks.length,
        'rawBlockCount': snapshot.docs.length,
      },
    );
    return blocks;
  }

  Future<ExamDojoProgressSummary> fetchSubjectProgress({
    required String userId,
    required String dojoId,
  }) async {
    ExamDojoLogger.log(
      'repository.progress.fetch',
      details: {'userId': userId, 'dojoId': dojoId},
    );
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('studyBlocks')
        .where('dojoId', isEqualTo: dojoId)
        .get();

    final Map<String, _SubjectProgressAccumulator> accumulators = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final subjectId = data['subjectId']?.toString();
      final subjectName = data['subjectName']?.toString() ??
          data['subject']?.toString() ??
          'Subject';
      final key =
          (subjectId != null && subjectId.isNotEmpty) ? subjectId : subjectName;
      final accumulator = accumulators.putIfAbsent(
        key,
        () => _SubjectProgressAccumulator(
          subjectId: subjectId,
          subjectName: subjectName,
        ),
      );
      accumulator.total += 1;
      final status = data['status']?.toString().toLowerCase();
      final isCompleted = data['isCompleted'] == true ||
          status == 'completed' ||
          status == 'done' ||
          status == 'finished';
      if (isCompleted) {
        accumulator.completed += 1;
      }
    }

    final subjects = accumulators.values
        .map(
          (acc) => ExamDojoSubjectProgressStat(
            subjectId: acc.subjectId,
            subjectName: acc.subjectName,
            completedBlocks: acc.completed,
            totalBlocks: acc.total,
          ),
        )
        .toList();

    return ExamDojoProgressSummary(subjects: subjects);
  }

  Future<void> generateRoadmap({
    required String dojoId,
    required DateTime studyWindowStart,
    required DateTime studyWindowEnd,
    required int weeklyLoadMinutes,
    String? notes,
  }) async {
    ExamDojoLogger.log(
      'repository.generateRoadmap.request',
      details: {
        'dojoId': dojoId,
        'start': studyWindowStart.toIso8601String(),
        'end': studyWindowEnd.toIso8601String(),
        'weeklyMinutes': weeklyLoadMinutes,
      },
    );
    final response = await _apiService.generateRoadmap(
      dojoId: dojoId,
      studyWindowStart: studyWindowStart,
      studyWindowEnd: studyWindowEnd,
      weeklyLoadMinutes: weeklyLoadMinutes,
      notes: notes,
    );
    ExamDojoLogger.log(
      'repository.generateRoadmap.response',
      details: {
        'dojoId': dojoId,
        'version': response['version'],
        'summary': response['studyBlocksSummary'],
      },
    );
  }

  String _resolveTimezone() {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes =
        (offset.inMinutes.abs() - offset.inHours.abs() * 60).toString().padLeft(
              2,
              '0',
            );
    final sign = offset.isNegative ? '-' : '+';
    return 'UTC$sign$hours:$minutes';
  }

  String _formatDateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _blockIdentity(ExamDojoDailyBlock block) {
    if (block.roadmapRef != null && block.roadmapRef!.isNotEmpty) {
      return block.roadmapRef!;
    }
    if (block.id.isNotEmpty) return block.id;
    final subject = block.subjectId ?? block.subjectName ?? 'subject';
    final chapter = block.chapterId ?? block.chapter ?? 'chapter';
    return '${block.date}::$subject::$chapter';
  }

  bool _shouldReplaceStoredBlock({
    required String preferredKey,
    required ExamDojoDailyBlock current,
    required ExamDojoDailyBlock candidate,
  }) {
    if (candidate.id == preferredKey && current.id != preferredKey) {
      return true;
    }
    if (current.id == preferredKey && candidate.id != preferredKey) {
      return false;
    }
    final currentDate = current.sessionDate ??
        DateTime.tryParse('${current.date}T00:00:00') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final candidateDate = candidate.sessionDate ??
        DateTime.tryParse('${candidate.date}T00:00:00') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (candidateDate.isAfter(currentDate)) return true;
    return false;
  }
}

class _SubjectProgressAccumulator {
  _SubjectProgressAccumulator({
    required this.subjectId,
    required this.subjectName,
  });

  final String? subjectId;
  final String subjectName;
  int completed = 0;
  int total = 0;
}
