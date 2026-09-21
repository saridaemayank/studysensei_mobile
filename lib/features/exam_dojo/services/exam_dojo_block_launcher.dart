import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/exam_dojo_daily_block.dart';
import 'exam_dojo_logger.dart';

class ExamDojoBlockLauncher {
  ExamDojoBlockLauncher({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> ensureStudyBlockFromDaily({
    required ExamDojoDailyBlock block,
    required String dojoId,
  }) {
    return _ensureStudyBlock(
      blockId: block.id,
      dojoId: dojoId,
      dateString: block.date,
      subjectId: block.subjectId,
      subjectName: block.subjectName,
      chapterId: block.chapterId,
      chapterName: block.chapter,
      blockType: block.blockType,
      durationMinutes: block.durationMinutes,
      notes: block.notes,
      roadmapRef: block.roadmapRef ?? block.id,
    );
  }

  Future<void> ensureStudyBlockFromRoadmap({
    required ExamDojoDailyBlock block,
    required String dojoId,
  }) {
    final targetDate = block.sessionDate ??
        _parseDate(block.date.isNotEmpty ? block.date : '');
    final dateKey =
        block.date.isNotEmpty ? block.date : _formatDate(targetDate);
    return _ensureStudyBlock(
      blockId: block.id,
      dojoId: dojoId,
      dateString: dateKey,
      sessionDateOverride: targetDate,
      subjectId: block.subjectId,
      subjectName: block.subjectName,
      chapterId: block.chapterId,
      chapterName: block.chapter,
      blockType: block.blockType,
      durationMinutes: block.durationMinutes,
      notes: block.notes,
      roadmapRef: block.roadmapRef ?? block.id,
    );
  }

  Future<void> _ensureStudyBlock({
    required String blockId,
    required String dojoId,
    required String dateString,
    String? subjectId,
    String? subjectName,
    String? chapterId,
    String? chapterName,
    String? blockType,
    required int durationMinutes,
    String? notes,
    String? roadmapRef,
    DateTime? sessionDateOverride,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You need to be signed in to start a study block.');
    }
    final collection =
        _firestore.collection('users').doc(user.uid).collection('studyBlocks');

    final requestedId = blockId.isNotEmpty ? blockId : '';
    final docId = await _resolveBlockDocumentId(
      collection: collection,
      requestedId: requestedId,
      dojoId: dojoId,
      roadmapRef: roadmapRef,
    );
    final scheduledAt = sessionDateOverride ?? _parseDate(dateString);
    final dateKey = sessionDateOverride != null
        ? _formatDate(sessionDateOverride)
        : dateString;

    ExamDojoLogger.log(
      'blockLauncher.ensureStudyBlock.start',
      details: {
        'userId': user.uid,
        'dojoId': dojoId,
        'targetDate': dateString,
        'sourceBlockId': blockId,
        'resolvedBlockId': docId,
      },
    );
    try {
      await collection.doc(docId).set({
        'userId': user.uid,
        'dojoId': dojoId,
        'title': chapterName ?? subjectName ?? 'Study Block',
        'subject': subjectName,
        'subjectName': subjectName,
        'subjectId': subjectId,
        'chapter': chapterName,
        'chapterName': chapterName,
        'chapterId': chapterId,
        'blockType': blockType,
        'durationMinutes': durationMinutes,
        'notes': notes,
        'roadmapRef': roadmapRef ?? docId,
        'status': 'pending',
        'isCompleted': false,
        'date': dateKey,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'sessionDate': Timestamp.fromDate(scheduledAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      ExamDojoLogger.log(
        'blockLauncher.ensureStudyBlock.success',
        details: {
          'userId': user.uid,
          'dojoId': dojoId,
          'blockId': docId,
        },
      );
    } catch (error) {
      ExamDojoLogger.log(
        'blockLauncher.ensureStudyBlock.error',
        details: {
          'userId': user.uid,
          'dojoId': dojoId,
          'blockId': docId,
          'message': error.toString(),
        },
      );
      rethrow;
    }
  }

  Future<String> _resolveBlockDocumentId({
    required CollectionReference<Map<String, dynamic>> collection,
    required String requestedId,
    required String dojoId,
    String? roadmapRef,
  }) async {
    if (requestedId.isNotEmpty) {
      final existing = await collection.doc(requestedId).get();
      if (existing.exists) return requestedId;
    }
    if (roadmapRef != null && roadmapRef.isNotEmpty) {
      try {
        final query = await collection
            .where('dojoId', isEqualTo: dojoId)
            .where('roadmapRef', isEqualTo: roadmapRef)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return query.docs.first.id;
        }
      } catch (error) {
        ExamDojoLogger.log(
          'blockLauncher.ensureStudyBlock.lookupError',
          details: {'message': error.toString(), 'roadmapRef': roadmapRef},
        );
      }
    }
    return requestedId.isNotEmpty ? requestedId : collection.doc().id;
  }

  DateTime _parseDate(String raw) {
    if (raw.isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null && parsed.year > 1900) {
          return DateTime(parsed.year, parsed.month, parsed.day, 8);
        }
        final parts = raw.split('-').map(int.tryParse).toList();
        if (parts.length == 3 &&
            parts[0] != null &&
            parts[1] != null &&
            parts[2] != null) {
          return DateTime(parts[0]!, parts[1]!, parts[2]!, 8);
        }
      } catch (_) {
        // ignore fallthrough to now
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 8);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
