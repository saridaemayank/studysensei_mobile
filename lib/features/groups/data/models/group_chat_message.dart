import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class GroupChatMessage extends Equatable {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime sentAt;
  final DateTime? editedAt;
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final String? replyPreview;

  const GroupChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.senderPhotoUrl,
    this.editedAt,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToSenderName,
    this.replyPreview,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (replyPreview != null) 'replyPreview': replyPreview,
    };
  }

  factory GroupChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String groupId,
  ) {
    final data = doc.data() ?? {};

    DateTime sentAt = DateTime.now();
    final sentAtRaw = data['sentAt'];
    if (sentAtRaw is Timestamp) {
      sentAt = sentAtRaw.toDate();
    } else if (sentAtRaw is DateTime) {
      sentAt = sentAtRaw;
    } else if (sentAtRaw is String) {
      sentAt = DateTime.tryParse(sentAtRaw) ?? sentAt;
    }

    DateTime? editedAt;
    final editedAtRaw = data['editedAt'];
    if (editedAtRaw is Timestamp) {
      editedAt = editedAtRaw.toDate();
    } else if (editedAtRaw is DateTime) {
      editedAt = editedAtRaw;
    } else if (editedAtRaw is String) {
      editedAt = DateTime.tryParse(editedAtRaw);
    }

    return GroupChatMessage(
      id: doc.id,
      groupId: groupId,
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'Unknown',
      senderPhotoUrl: data['senderPhotoUrl']?.toString(),
      text: data['text']?.toString() ?? '',
      sentAt: sentAt,
      editedAt: editedAt,
      replyToMessageId: data['replyToMessageId']?.toString(),
      replyToSenderId: data['replyToSenderId']?.toString(),
      replyToSenderName: data['replyToSenderName']?.toString(),
      replyPreview: data['replyPreview']?.toString(),
    );
  }

  bool get isEdited => editedAt != null;

  @override
  List<Object?> get props => [
        id,
        groupId,
        senderId,
        senderName,
        senderPhotoUrl,
        text,
        sentAt,
        editedAt,
        replyToMessageId,
        replyToSenderId,
        replyToSenderName,
        replyPreview,
      ];
}
