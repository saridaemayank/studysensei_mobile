import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class DojoAnnouncement extends Equatable {
  const DojoAnnouncement(
      {required this.id,
      required this.dojoId,
      required this.title,
      required this.body,
      required this.createdBy,
      required this.createdByName,
      required this.createdAt});
  final String id, dojoId, title, body, createdBy, createdByName;
  final DateTime createdAt;
  factory DojoAnnouncement.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc, String dojoId) {
    final d = doc.data() ?? {};
    return DojoAnnouncement(
        id: doc.id,
        dojoId: dojoId,
        title: d['title']?.toString() ?? '',
        body: d['body']?.toString() ?? '',
        createdBy: d['createdBy']?.toString() ?? '',
        createdByName: d['createdByName']?.toString() ?? 'Dojo admin',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now());
  }
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp()
      };
  @override
  List<Object?> get props =>
      [id, dojoId, title, body, createdBy, createdByName, createdAt];
}
