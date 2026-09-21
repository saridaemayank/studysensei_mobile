import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/groups/data/models/dojo_announcement.dart';
import 'package:study_sensei/features/groups/data/models/dojo_pin.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

class DojoEngagementService {
  DojoEngagementService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  CollectionReference<Map<String, dynamic>> _items(String dojo, String name) =>
      _firestore.collection('groups').doc(dojo).collection(name);
  bool _isAdmin(Group g, String uid) =>
      g.createdBy == uid || g.adminIds.contains(uid);
  Stream<List<DojoPin>> watchPins(String dojoId) => _items(dojoId, 'pins')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => DojoPin.fromDocument(d, dojoId)).toList());
  Stream<List<DojoAnnouncement>> watchAnnouncements(String dojoId) =>
      _items(dojoId, 'announcements')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((s) => s.docs
              .map((d) => DojoAnnouncement.fromDocument(d, dojoId))
              .toList());
  Future<void> pin(
      {required Group group,
      required DojoPinType type,
      required String targetId,
      required String name,
      String? preview}) async {
    final u = _auth.currentUser;
    if (u == null || !_isAdmin(group, u.uid)) {
      throw StateError('not-authorized');
    }
    await _items(group.id, 'pins').add(DojoPin(
            id: '',
            dojoId: group.id,
            type: type,
            targetId: targetId,
            pinnedBy: u.uid,
            pinnedByName: name,
            createdAt: DateTime.now(),
            preview: preview?.substring(0, preview.length.clamp(0, 160)))
        .toMap());
  }

  Future<void> unpin({required Group group, required String pinId}) async {
    final u = _auth.currentUser;
    if (u == null || !_isAdmin(group, u.uid)) {
      throw StateError('not-authorized');
    }
    await _items(group.id, 'pins').doc(pinId).delete();
  }

  Future<void> createAnnouncement(
      {required Group group,
      required String title,
      required String body,
      required String name}) async {
    final u = _auth.currentUser;
    if (u == null || !_isAdmin(group, u.uid)) {
      throw StateError('not-authorized');
    }
    await _items(group.id, 'announcements').add(DojoAnnouncement(
            id: '',
            dojoId: group.id,
            title: title.trim(),
            body: body.trim(),
            createdBy: u.uid,
            createdByName: name,
            createdAt: DateTime.now())
        .toMap());
  }

  Future<void> deleteAnnouncement(
      {required Group group, required String id}) async {
    final u = _auth.currentUser;
    if (u == null || !_isAdmin(group, u.uid)) {
      throw StateError('not-authorized');
    }
    await _items(group.id, 'announcements').doc(id).delete();
    // Pins are denormalized references. Clean them up after the announcement
    // deletion; a failed cleanup cannot resurrect the deleted announcement.
    try {
      final pins = await _items(group.id, 'pins')
          .where('type', isEqualTo: DojoPinType.announcement.name)
          .where('targetId', isEqualTo: id)
          .get();
      final batch = _firestore.batch();
      for (final pin in pins.docs) {
        batch.delete(pin.reference);
      }
      if (pins.docs.isNotEmpty) await batch.commit();
    } catch (_) {
      // The pins panel tolerates stale target references. Keep a failed cleanup
      // from turning a successful deletion into an error for the admin.
    }
  }
}
