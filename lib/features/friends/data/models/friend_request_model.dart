import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestModel {
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final DateTime sentAt;

  FriendRequestModel({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.sentAt,
  });

  factory FriendRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequestModel(
      requestId: id,
      senderId: map['fromUserId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      senderEmail: map['senderEmail'] ?? '',
      sentAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'createdAt': sentAt,
    };
  }
}
