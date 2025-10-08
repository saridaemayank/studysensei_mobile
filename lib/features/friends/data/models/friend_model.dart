class Friend {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  Friend({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  factory Friend.fromMap(Map<String, dynamic> map, String id) {
    return Friend(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}
