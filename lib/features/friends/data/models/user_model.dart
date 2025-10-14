import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? searchUid; // First 5 characters of UID for search
  final DateTime? createdAt;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.searchUid,
    this.createdAt,
    this.photoUrl,
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
    };
  }

  // Create model from Firestore document
  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      searchUid: map['searchUid'] ?? id.substring(0, 5).toLowerCase(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      photoUrl: map['photoUrl']?.toString(),
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
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      searchUid: searchUid ?? this.searchUid,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
