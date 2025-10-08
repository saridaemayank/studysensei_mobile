import 'package:cloud_firestore/cloud_firestore.dart';

class UserPreferences {
  // Helper method to format date from dynamic type
  static String _formatDate(dynamic date) {
    if (date == null) return '';
    
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } else if (date is DateTime) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } else if (date is String) {
      return date;
    }
    return date.toString();
  }
  final String? userId;
  final String? name;
  final String? email;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;
  final List<String>? subjects;
  final String? preferredTheme;
  final bool? notificationsEnabled;

  UserPreferences({
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.subjects,
    this.preferredTheme = 'system',
    this.notificationsEnabled = true,
  });

  // Convert UserPreferences to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'subjects': subjects,
      'preferredTheme': preferredTheme,
      'notificationsEnabled': notificationsEnabled,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // Create UserPreferences from Firestore document
  factory UserPreferences.fromMap(Map<String, dynamic> map, String documentId) {
    print('Creating UserPreferences from map: $map');

    // Handle different field name variations
    final name =
        map['displayName'] ??
        map['name'] ??
        '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}'.trim();
    final email = map['email'] ?? '';
    final phone = map['phoneNumber'] ?? map['phone'] ?? '';
    final dateOfBirth = map['dateOfBirth'] ?? map['dob'] ?? map['birthDate'];
    final gender = map['gender'] ?? '';

    return UserPreferences(
      userId: documentId,
      name: name.isNotEmpty ? name : 'User $documentId',
      email: email,
      phone: phone.toString(),
      dateOfBirth: _formatDate(dateOfBirth),
      gender: gender.toString(),
      subjects: List<String>.from(map['subjects'] ?? []),
      preferredTheme: map['preferredTheme']?.toString() ?? 'system',
      notificationsEnabled: map['notificationsEnabled'] ?? true,
    );
  }


  // Create a copy of UserPreferences with some fields updated
  UserPreferences copyWith({
    String? name,
    String? email,
    String? phone,
    String? dateOfBirth,
    String? gender,
    List<String>? subjects,
    String? preferredTheme,
    bool? notificationsEnabled,
  }) {
    return UserPreferences(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      subjects: subjects ?? this.subjects,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
