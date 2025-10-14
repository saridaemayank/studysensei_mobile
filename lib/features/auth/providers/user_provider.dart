import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  UserPreferences? _userPreferences;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  UserPreferences? get userPreferences => _userPreferences;

  // Initialize auth state listener
  void initAuth() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserPreferences(user.uid);
      } else {
        _userPreferences = null;
      }
      notifyListeners();
    });
  }

  // Load user data from Firestore
  Future<void> _loadUserPreferences(String userId) async {
    try {
      // First try to get from users collection
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        debugPrint('Firestore User Data: ${userDoc.data()}');
        _userPreferences = UserPreferences.fromMap(userDoc.data()!, userId);
      } else {
        // Fallback to userPreferences collection for backward compatibility
        final prefsDoc = await _firestore
            .collection('userPreferences')
            .doc(userId)
            .get();
        if (prefsDoc.exists) {
          debugPrint('Firestore Preferences Data: ${prefsDoc.data()}');
          _userPreferences = UserPreferences.fromMap(prefsDoc.data()!, userId);
        } else {
          // Create default preferences if not exists
          _userPreferences = UserPreferences(userId: userId);
          await _savePreferences();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing user preferences: $e');
      rethrow;
    }
  }

  // Sign out - clears authentication and user data
  Future<void> signOut() async {
    try {
      // Clear local state first
      _user = null;
      _userPreferences = null;

      // Clear any pending operations
      await Future.wait([
        // Add any other cleanup operations here
        Future.delayed(Duration.zero),
      ]);

      notifyListeners();
    } catch (e) {
      debugPrint('Error during signOut cleanup: $e');
      rethrow;
    }
  }

  // Update user preferences
  Future<void> updatePreferences({
    String? name,
    String? email,
    String? phone,
    String? dateOfBirth,
    String? gender,
    List<String>? subjects,
    String? preferredTheme,
    bool? notificationsEnabled,
    String? photoUrl,
  }) async {
    if (_userPreferences == null) return;

    _userPreferences = _userPreferences!.copyWith(
      name: name,
      email: email,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      subjects: subjects,
      preferredTheme: preferredTheme,
      notificationsEnabled: notificationsEnabled,
      photoUrl: photoUrl,
    );

    await _savePreferences();
    notifyListeners();
  }

  // Save preferences to Firestore
  Future<void> _savePreferences() async {
    if (_userPreferences == null || _user == null) return;

    try {
      await _firestore
          .collection('userPreferences')
          .doc(_user!.uid)
          .set(_userPreferences!.toMap());
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
      rethrow;
    }
  }

  // Clear user data on logout
  void clearUser() {
    _userPreferences = null;
    notifyListeners();
  }

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // The auth state listener will handle the rest
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.code} - ${e.message}');
      rethrow; // Re-throw to be handled by the caller
    }
  }
}
