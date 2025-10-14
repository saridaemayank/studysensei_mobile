import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required DateTime dateOfBirth,
    required String gender,
    Uint8List? profileImageBytes,
    String? profileImageFileName,
  }) async {
    try {
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      String? photoUrl;
      if (profileImageBytes != null) {
        photoUrl = await _uploadProfilePicture(
          userCredential.user!.uid,
          profileImageBytes,
          profileImageFileName,
        );
      }

      // Update display name in Firebase Auth
      await userCredential.user?.updateDisplayName(name.trim());
      if (photoUrl != null) {
        await userCredential.user?.updatePhotoURL(photoUrl);
      }

      // Create user document in Firestore
      await _createUserDocument(
        userCredential.user!.uid,
        name,
        email,
        phone,
        dateOfBirth,
        gender,
        photoUrl: photoUrl,
      );

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(
    String uid,
    String name,
    String email,
    String phone,
    DateTime dateOfBirth,
    String gender, {
    String? photoUrl,
  }) async {
    final data = {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    await _firestore.collection('users').doc(uid).set(data);
  }

  Future<String?> _uploadProfilePicture(
    String uid,
    Uint8List bytes,
    String? fileName,
  ) async {
    final fileExtension = (fileName != null && fileName.contains('.'))
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    String contentType = 'image/jpeg';
    if (fileExtension == 'png') {
      contentType = 'image/png';
    } else if (fileExtension == 'gif') {
      contentType = 'image/gif';
    }

    final ref = _storage.ref().child('profile_pictures/$uid.$fileExtension');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return uploadTask.ref.getDownloadURL();
  }

  // Add subjects for user
  Future<void> addUserSubjects(List<String> subjects) async {
    final user = currentUser;
    if (user != null) {
      await _firestore.collection('user_subjects').doc(user.uid).set({
        'subjects': subjects,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get user subjects
  Future<List<String>> getUserSubjects() async {
    final user = currentUser;
    if (user != null) {
      final doc =
          await _firestore.collection('user_subjects').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['subjects'] ?? []);
      }
    }
    return [];
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
