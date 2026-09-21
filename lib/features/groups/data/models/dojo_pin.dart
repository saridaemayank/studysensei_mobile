import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum DojoPinType { message, resource, announcement }

class DojoPin extends Equatable {
  const DojoPin(
      {required this.id,
      required this.dojoId,
      required this.type,
      required this.targetId,
      required this.pinnedBy,
      required this.pinnedByName,
      required this.createdAt,
      this.preview});
  final String id, dojoId, targetId, pinnedBy, pinnedByName;
  final DojoPinType type;
  final DateTime createdAt;
  final String? preview;
  factory DojoPin.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc, String dojoId) {
    final d = doc.data() ?? {};
    return DojoPin(
        id: doc.id,
        dojoId: dojoId,
        type: DojoPinType.values.firstWhere((v) => v.name == d['type'],
            orElse: () => DojoPinType.message),
        targetId: d['targetId']?.toString() ?? '',
        pinnedBy: d['pinnedBy']?.toString() ?? '',
        pinnedByName: d['pinnedByName']?.toString() ?? 'Dojo member',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        preview: d['preview']?.toString());
  }
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'targetId': targetId,
        'pinnedBy': pinnedBy,
        'pinnedByName': pinnedByName,
        'createdAt': FieldValue.serverTimestamp(),
        if (preview != null) 'preview': preview
      };
  @override
  List<Object?> get props =>
      [id, dojoId, type, targetId, pinnedBy, pinnedByName, createdAt, preview];
}
