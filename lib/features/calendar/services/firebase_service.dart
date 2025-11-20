import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get users collection reference
  static CollectionReference<Map<String, dynamic>> get _usersCollection {
    return FirebaseFirestore.instance.collection('users');
  }

  // Safe getter for current user's document reference
  static DocumentReference<Map<String, dynamic>>? _userDocOrNull() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return _usersCollection.doc(user.uid);
  }

  // Get current user document reference
  static DocumentReference<Map<String, dynamic>> get _userDoc {
    final doc = _userDocOrNull();
    if (doc == null) {
      throw Exception('User not logged in');
    }
    return doc;
  }

  // Get current user's subjects subcollection reference
  static CollectionReference<Map<String, dynamic>> get _userSubjectsCollection {
    return _userDoc.collection('subjects');
  }

  // Get user's assignments subcollection
  static CollectionReference<Map<String, dynamic>> get _assignmentsCollection =>
      _userDoc.collection('assignments');

  // Get all assignments for current user
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAssignments() {
    final doc = _userDocOrNull();
    if (doc == null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return doc
        .collection('assignments')
        .orderBy('deadline')
        .snapshots()
        .handleError(
          (_) {},
          test: (error) =>
              error is FirebaseException && error.code == 'permission-denied',
        );
  }

  // Add a new assignment for current user
  static Future<void> addAssignment({
    required String name,
    required String subject,
    required DateTime deadline,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final assignmentData = {
      'name': name,
      'subject': subject,
      'deadline': Timestamp.fromDate(deadline),
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final publicAssignmentData = {
      ...assignmentData,
      'userId': user.uid,
    };

    final batch = _firestore.batch();

    final userAssignmentRef = _assignmentsCollection.doc();
    final publicAssignmentRef =
        _firestore.collection('assignments').doc(); // Public collection

    batch.set(userAssignmentRef, assignmentData);
    batch.set(publicAssignmentRef, publicAssignmentData);

    await batch.commit();
  }

  // Delete an assignment for current user
  static Future<void> deleteAssignment(String id) async {
    await _assignmentsCollection.doc(id).delete();
  }

  // Update an assignment for current user
  static Future<void> updateAssignment({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _assignmentsCollection.doc(id).update(data);
  }

  // Add a subject to user's subjects subcollection
  static Future<void> addSubject(String subject) async {
    await _userSubjectsCollection.add({
      'name': subject,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get all subjects for current user
  static Stream<List<String>> getUserSubjects() {
    final doc = _userDocOrNull();
    if (doc == null) {
      return const Stream.empty();
    }

    return doc
        .collection('subjects')
        .orderBy('name')
        .snapshots()
        .handleError(
          (_) {},
          test: (error) =>
              error is FirebaseException && error.code == 'permission-denied',
        )
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc['name'] as String).toList(),
        );
  }

  // Update user data
  static Future<void> updateUserData({
    required String name,
    required String email,
    required List<String> subjects,
    required String grade,
  }) async {
    try {
      // Update user document
      await _userDoc.set({
        'name': name,
        'email': email,
        'grade': grade,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update subjects subcollection
      final batch = _firestore.batch();

      // Clear existing subjects
      final existingSubjects = await _userSubjectsCollection.get();
      for (var doc in existingSubjects.docs) {
        batch.delete(doc.reference);
      }

      // Add new subjects
      for (var subject in subjects) {
        batch.set(_userSubjectsCollection.doc(), {
          'name': subject,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  // Get user document
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    final doc = _userDocOrNull();
    if (doc == null) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return doc.snapshots().handleError(
          (_) {},
          test: (error) =>
              error is FirebaseException && error.code == 'permission-denied',
        );
  }
}
