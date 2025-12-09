import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudySessionRepository {
  StudySessionRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _sessionCollection {
    return _firestore.collection('users').doc(_userId).collection('studySessions');
  }

  Future<DocumentReference<Map<String, dynamic>>> createSession(
    Map<String, dynamic> data,
  ) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    return _sessionCollection.add(data);
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _sessionCollection.doc(sessionId).update(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> findActiveSession({
    String? assignmentId,
    String? studyBlockId,
  }) async {
    if (assignmentId == null && studyBlockId == null) {
      return null;
    }

    Query<Map<String, dynamic>> query;
    if (assignmentId != null) {
      query = _sessionCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .limit(5);
    } else {
      query = _sessionCollection
          .where('studyBlockId', isEqualTo: studyBlockId)
          .limit(5);
    }

    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      final status = doc.data()['completionStatus'] as String? ?? 'ongoing';
      if (status == 'ongoing') {
        return doc;
      }
    }
    return null;
  }
}
