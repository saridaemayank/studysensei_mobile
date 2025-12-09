import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? searchUid; // First 5 characters of UID for search
  final DateTime? createdAt;
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final String? gender;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.searchUid,
    this.createdAt,
    this.photoUrl,
    this.dateOfBirth,
    this.gender,
  });

  // Convert model to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'searchUid': searchUid ?? id.substring(0, 5).toLowerCase(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
    };
  }

  // Create model from Firestore document
  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      searchUid: map['searchUid'] ?? id.substring(0, 5).toLowerCase(),
      createdAt: parseDate(map['createdAt']),
      photoUrl: map['photoUrl']?.toString(),
      dateOfBirth: parseDate(
        map['dateOfBirth'] ?? map['dob'] ?? map['birthDate'],
      ),
      gender: map['gender']?.toString(),
    );
  }

  // Create a copy of the model with updated fields
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? searchUid,
    DateTime? createdAt,
    String? photoUrl,
    DateTime? dateOfBirth,
    String? gender,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      searchUid: searchUid ?? this.searchUid,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
    );
  }
}
