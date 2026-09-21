import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:study_sensei/features/groups/data/models/dojo_resource.dart';
import 'package:study_sensei/features/groups/data/models/dojo_resource_file.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/services/dojo_resource_validation.dart';

enum DojoResourceErrorCode {
  unsupportedType,
  tooLarge,
  unauthenticated,
  notMember,
  permissionDenied,
  uploadFailed,
  networkUnavailable,
  openFailed,
  deleteFailed,
}

class DojoResourceException implements Exception {
  final DojoResourceErrorCode code;

  const DojoResourceException(this.code);

  String get userMessage => switch (code) {
        DojoResourceErrorCode.unsupportedType =>
          "This file type isn't supported yet.",
        DojoResourceErrorCode.tooLarge =>
          'This file is too large. Choose a file under 25 MB.',
        DojoResourceErrorCode.unauthenticated => 'Sign in to upload resources.',
        DojoResourceErrorCode.notMember =>
          "You don't have permission to upload here.",
        DojoResourceErrorCode.permissionDenied =>
          "You don't have permission to upload here.",
        DojoResourceErrorCode.openFailed => "Couldn't open this resource.",
        DojoResourceErrorCode.deleteFailed =>
          "Couldn't delete this resource. Try again.",
        DojoResourceErrorCode.uploadFailed =>
          "Couldn't upload this resource. Try again.",
        DojoResourceErrorCode.networkUnavailable =>
          'Upload failed. Check your connection and try again.',
      };
}

class DojoResourceUser {
  final String uid;

  const DojoResourceUser({required this.uid});
}

class DojoResourceUploadProgress {
  final int transferredBytes;
  final int totalBytes;

  const DojoResourceUploadProgress({
    required this.transferredBytes,
    required this.totalBytes,
  });

  double get value => totalBytes <= 0 ? 0 : transferredBytes / totalBytes;
}

abstract class DojoResourceAuth {
  Future<DojoResourceUser?> currentUser();
}

class FirebaseDojoResourceAuth implements DojoResourceAuth {
  final firebase_auth.FirebaseAuth auth;

  const FirebaseDojoResourceAuth({required this.auth});

  @override
  Future<DojoResourceUser?> currentUser() async {
    final user = auth.currentUser;
    if (user == null) return null;
    return DojoResourceUser(uid: user.uid);
  }
}

abstract class DojoResourcePicker {
  Future<DojoResourceFile?> pickResource();
}

class FileSelectorDojoResourcePicker implements DojoResourcePicker {
  const FileSelectorDojoResourcePicker();

  // file_selector_iOS requires Uniform Type Identifiers for every restricted
  // group. Extensions and MIME types continue to filter the Android picker.
  static const XTypeGroup supportedTypeGroup = XTypeGroup(
    label: 'Study resources',
    extensions: [
      'pdf',
      'doc',
      'docx',
      'ppt',
      'pptx',
      'jpg',
      'jpeg',
      'png',
      'webp',
    ],
    mimeTypes: [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'image/jpeg',
      'image/png',
      'image/webp',
    ],
    uniformTypeIdentifiers: [
      'com.adobe.pdf',
      'com.microsoft.word.doc',
      'org.openxmlformats.wordprocessingml.document',
      'com.microsoft.powerpoint.ppt',
      'org.openxmlformats.presentationml.presentation',
      'public.image',
    ],
  );

  @override
  Future<DojoResourceFile?> pickResource() async {
    final file = await openFile(
      acceptedTypeGroups: const [supportedTypeGroup],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mimeType =
        DojoResourceValidation.mimeTypeFor(file.name, file.mimeType);
    return DojoResourceFile(
      name: file.name,
      extension: DojoResourceValidation.extensionFor(file.name),
      mimeType: mimeType,
      sizeBytes: bytes.length,
      bytes: bytes,
    );
  }
}

abstract class DojoResourceStorage {
  Future<String> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    required String uploadedBy,
    void Function(DojoResourceUploadProgress progress)? onProgress,
  });

  Future<void> delete(String storagePath);
}

class FirebaseDojoResourceStorage implements DojoResourceStorage {
  final FirebaseStorage storage;

  const FirebaseDojoResourceStorage({required this.storage});

  @override
  Future<String> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    required String uploadedBy,
    void Function(DojoResourceUploadProgress progress)? onProgress,
  }) async {
    final ref = storage.ref().child(storagePath);
    final task = ref.putData(
      bytes,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: {'uploadedBy': uploadedBy},
      ),
    );

    StreamSubscription<TaskSnapshot>? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen((snapshot) {
        onProgress(DojoResourceUploadProgress(
          transferredBytes: snapshot.bytesTransferred,
          totalBytes: snapshot.totalBytes,
        ));
      });
    }

    try {
      await task;
      return ref.getDownloadURL();
    } finally {
      await sub?.cancel();
    }
  }

  @override
  Future<void> delete(String storagePath) async {
    try {
      await storage.ref().child(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}

abstract class DojoResourceMetadataStore {
  Stream<List<DojoResource>> watchResources(String dojoId);

  Future<void> createResource(DojoResource resource);

  Future<void> deleteResource(String dojoId, String resourceId);
}

class FirestoreDojoResourceMetadataStore implements DojoResourceMetadataStore {
  final FirebaseFirestore firestore;

  const FirestoreDojoResourceMetadataStore({required this.firestore});

  CollectionReference<Map<String, dynamic>> _resources(String dojoId) =>
      firestore.collection('groups').doc(dojoId).collection('resources');

  @override
  Stream<List<DojoResource>> watchResources(String dojoId) {
    return _resources(dojoId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DojoResource.fromFirestore(doc, dojoId))
            .toList());
  }

  @override
  Future<void> createResource(DojoResource resource) {
    return _resources(resource.dojoId).doc(resource.id).set(
          resource.toFirestore(useServerTimestamp: true),
        );
  }

  @override
  Future<void> deleteResource(String dojoId, String resourceId) {
    return _resources(dojoId).doc(resourceId).delete();
  }
}

class DojoResourceService {
  final DojoResourceAuth auth;
  final DojoResourcePicker picker;
  final DojoResourceStorage storage;
  final DojoResourceMetadataStore metadataStore;
  final Uuid uuid;

  DojoResourceService({
    DojoResourceAuth? auth,
    DojoResourcePicker? picker,
    DojoResourceStorage? storage,
    DojoResourceMetadataStore? metadataStore,
    Uuid? uuid,
  })  : auth = auth ??
            FirebaseDojoResourceAuth(auth: firebase_auth.FirebaseAuth.instance),
        picker = picker ?? const FileSelectorDojoResourcePicker(),
        storage = storage ??
            FirebaseDojoResourceStorage(storage: FirebaseStorage.instance),
        metadataStore = metadataStore ??
            FirestoreDojoResourceMetadataStore(
              firestore: FirebaseFirestore.instance,
            ),
        uuid = uuid ?? const Uuid();

  bool canDelete({
    required Group group,
    required DojoResource resource,
    required String userId,
  }) {
    return resource.uploadedBy == userId ||
        group.adminIds.contains(userId) ||
        group.createdBy == userId;
  }

  Stream<List<DojoResource>> watchResources(String dojoId) {
    return metadataStore.watchResources(dojoId);
  }

  Future<DojoResourceFile?> pickResource() => picker.pickResource();

  void validate(DojoResourceFile file) {
    if (!DojoResourceValidation.isSupported(file.name, file.mimeType)) {
      throw const DojoResourceException(DojoResourceErrorCode.unsupportedType);
    }
    if (file.sizeBytes > DojoResourceValidation.maxSizeBytes) {
      throw const DojoResourceException(DojoResourceErrorCode.tooLarge);
    }
  }

  Future<DojoResource> uploadResource({
    required Group group,
    required DojoResourceFile file,
    required String uploaderName,
    void Function(DojoResourceUploadProgress progress)? onProgress,
  }) async {
    final user = await auth.currentUser();
    if (user == null) {
      throw const DojoResourceException(DojoResourceErrorCode.unauthenticated);
    }
    if (!group.memberIds.contains(user.uid)) {
      throw const DojoResourceException(DojoResourceErrorCode.notMember);
    }
    validate(file);

    final resourceId = uuid.v4();
    final mimeType = DojoResourceValidation.canonicalMimeType(file.name);
    final storagePath = DojoResourceValidation.storagePath(
      dojoId: group.id,
      resourceId: resourceId,
      fileName: file.name,
    );
    String downloadUrl;

    try {
      downloadUrl = await storage.uploadBytes(
        storagePath: storagePath,
        bytes: file.bytes,
        mimeType: mimeType,
        uploadedBy: user.uid,
        onProgress: onProgress,
      );
    } on FirebaseException catch (error) {
      throw _uploadError(error.code);
    } catch (error) {
      debugPrint('Dojo resource upload failed: ${error.runtimeType}');
      throw const DojoResourceException(DojoResourceErrorCode.uploadFailed);
    }

    final displayName =
        file.name.trim().isEmpty ? 'Untitled resource' : file.name.trim();
    final resource = DojoResource(
      id: resourceId,
      dojoId: group.id,
      name: displayName,
      originalFileName: displayName,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      mimeType: mimeType,
      extension: DojoResourceValidation.extensionFor(file.name),
      sizeBytes: file.sizeBytes,
      uploadedBy: user.uid,
      uploadedByName:
          uploaderName.trim().isEmpty ? 'Dojo member' : uploaderName.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await metadataStore.createResource(resource);
      return resource;
    } on FirebaseException catch (error) {
      debugPrint('Dojo resource metadata create failed: ${error.code}');
      await _deleteOrphan(storagePath);
      if (error.code == 'permission-denied') {
        throw const DojoResourceException(
            DojoResourceErrorCode.permissionDenied);
      }
      throw const DojoResourceException(DojoResourceErrorCode.uploadFailed);
    } catch (_) {
      await _deleteOrphan(storagePath);
      throw const DojoResourceException(DojoResourceErrorCode.uploadFailed);
    }
  }

  Future<void> deleteResource({
    required Group group,
    required DojoResource resource,
  }) async {
    final user = await auth.currentUser();
    if (user == null) {
      throw const DojoResourceException(DojoResourceErrorCode.unauthenticated);
    }
    if (!canDelete(group: group, resource: resource, userId: user.uid)) {
      throw const DojoResourceException(DojoResourceErrorCode.permissionDenied);
    }

    try {
      await storage.delete(resource.storagePath);
      await metadataStore.deleteResource(group.id, resource.id);
    } on FirebaseException catch (error) {
      debugPrint('Dojo resource delete failed: ${error.code}');
      if (error.code == 'permission-denied' || error.code == 'unauthorized') {
        throw const DojoResourceException(
            DojoResourceErrorCode.permissionDenied);
      }
      throw const DojoResourceException(DojoResourceErrorCode.deleteFailed);
    } catch (_) {
      throw const DojoResourceException(DojoResourceErrorCode.deleteFailed);
    }
  }

  Future<void> openResource(DojoResource resource) async {
    final uri = Uri.tryParse(resource.downloadUrl);
    if (uri == null) {
      throw const DojoResourceException(DojoResourceErrorCode.openFailed);
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const DojoResourceException(DojoResourceErrorCode.openFailed);
    }
  }

  Future<void> _deleteOrphan(String storagePath) async {
    try {
      await storage.delete(storagePath);
    } catch (_) {
      debugPrint('Dojo resource orphan cleanup failed.');
    }
  }

  DojoResourceException _uploadError(String rawCode) {
    final code = rawCode.replaceFirst('storage/', '');
    debugPrint('Dojo resource upload failed: $code');
    if (code == 'permission-denied' || code == 'unauthorized') {
      return const DojoResourceException(
          DojoResourceErrorCode.permissionDenied);
    }
    if (code == 'network-request-failed' || code == 'retry-limit-exceeded') {
      return const DojoResourceException(
          DojoResourceErrorCode.networkUnavailable);
    }
    return const DojoResourceException(DojoResourceErrorCode.uploadFailed);
  }
}
