import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';
import 'package:study_sensei/features/groups/data/models/assignment_model.dart';

class Group extends Equatable {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final String? imageUrl;
  final List<String> adminIds;
  final List<String> memberIds;
  final GroupPrivacy privacy;
  final List<String> pendingInvites;
  final List<String> searchTerms;
  final List<Assignment> assignments;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl,
    List<String>? adminIds,
    List<String>? memberIds,
    required this.privacy,
    List<String>? pendingInvites,
    List<String>? searchTerms,
    List<Assignment>? assignments,
  })  : adminIds = adminIds ?? [createdBy],
        memberIds = memberIds ?? [createdBy],
        pendingInvites = pendingInvites ?? [],
        searchTerms = searchTerms ?? _generateSearchTerms(name, description),
        assignments = assignments ?? [];

  // Generate search terms from name and description
  static List<String> _generateSearchTerms(String name, String description) {
    final terms = <String>{};
    
    // Add full name and description in lowercase
    terms.add(name.toLowerCase());
    terms.add(description.toLowerCase());
    
    // Split into words and add each word
    terms.addAll(name.toLowerCase().split(' '));
    terms.addAll(description.toLowerCase().split(' '));
    
    // Remove empty strings and duplicates
    return terms.where((term) => term.isNotEmpty).toList();
  }

  // Convert model to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'imageUrl': imageUrl,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'privacy': privacy.toString(),
      'pendingInvites': pendingInvites,
      'isPublic': privacy == GroupPrivacy.public,
      'searchTerms': searchTerms,
      'assignments': assignments.map((a) => a.toJson()).toList(),
    };
  }

  // Create model from Firestore document
  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
      adminIds: List<String>.from(map['adminIds'] ?? []),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      privacy: GroupPrivacy.values.firstWhere(
        (e) => e.toString() == map['privacy'],
        orElse: () => GroupPrivacy.private,
      ),
      pendingInvites: List<String>.from(map['pendingInvites'] ?? []),
      searchTerms: List<String>.from(map['searchTerms'] ?? []),
      assignments: (map['assignments'] as List<dynamic>?)
              ?.map((a) => Assignment.fromJson(a))
              .toList() ??
          [],
    );
  }

  // Create a copy of the group with some updated fields
  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    String? imageUrl,
    List<String>? adminIds,
    List<String>? memberIds,
    GroupPrivacy? privacy,
    List<String>? pendingInvites,
    List<String>? searchTerms,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      privacy: privacy ?? this.privacy,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      searchTerms: searchTerms ?? this.searchTerms,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        createdBy,
        createdAt,
        imageUrl,
        searchTerms,
        adminIds,
        memberIds,
        privacy,
        pendingInvites,
      ];

  bool get isAdmin => adminIds.contains(createdBy);
  int get memberCount => memberIds.length;
  bool get isPrivate => privacy == GroupPrivacy.private;
  bool get isInviteOnly => privacy == GroupPrivacy.inviteOnly;
}
