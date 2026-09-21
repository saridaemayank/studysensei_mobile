import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';
import 'package:study_sensei/features/groups/data/models/dojo_resource.dart';
import 'package:study_sensei/features/groups/data/models/dojo_resource_file.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/services/dojo_resource_service.dart';
import 'package:study_sensei/features/groups/data/services/dojo_resource_validation.dart';
import 'package:study_sensei/features/groups/presentation/widgets/dojo_resources_tab.dart';

void main() {
  final dojo = Group(
    id: 'dojo-1',
    name: 'Physics Dojo',
    description: 'Current electricity prep',
    createdBy: 'owner',
    createdAt: DateTime(2026),
    privacy: GroupPrivacy.private,
    adminIds: const ['owner'],
    memberIds: const ['owner', 'me'],
  );

  DojoResourceFile file(
    String name, {
    int size = 1024,
    String? mimeType,
  }) {
    return DojoResourceFile(
      name: name,
      extension: DojoResourceValidation.extensionFor(name),
      mimeType: DojoResourceValidation.mimeTypeFor(name, mimeType),
      sizeBytes: size,
      bytes: Uint8List(size.clamp(0, 1024)),
    );
  }

  group('resource validation', () {
    test('native picker group includes the identifiers required by iOS', () {
      final typeGroup = FileSelectorDojoResourcePicker.supportedTypeGroup;

      expect(
          typeGroup.extensions, containsAll(['pdf', 'docx', 'pptx', 'webp']));
      expect(
        typeGroup.uniformTypeIdentifiers,
        containsAll(['com.adobe.pdf', 'public.image']),
      );
    });

    test('valid PDF DOCX PPTX and image files are accepted', () {
      expect(DojoResourceValidation.isSupported('notes.pdf', null), isTrue);
      expect(DojoResourceValidation.isSupported('essay.docx', null), isTrue);
      expect(DojoResourceValidation.isSupported('slides.pptx', null), isTrue);
      expect(DojoResourceValidation.isSupported('diagram.webp', null), isTrue);
    });

    test('unsupported type and files over 25MB are rejected', () {
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(null),
        storage: _Storage(),
        metadataStore: _Store(),
      );

      expect(
        () => service.validate(file('archive.zip')),
        throwsA(isA<DojoResourceException>()),
      );
      expect(
        () => service.validate(file('huge.pdf', size: 25 * 1024 * 1024 + 1)),
        throwsA(isA<DojoResourceException>()),
      );
    });

    test('filename sanitization removes path characters', () {
      expect(
        DojoResourceValidation.sanitizeFileName('../unit:test?.pdf'),
        '_unit_test_.pdf',
      );
      expect(
        DojoResourceValidation.storagePath(
          dojoId: 'dojo-1',
          resourceId: 'res-1',
          fileName: '../unit:test?.pdf',
        ),
        'dojos/dojo-1/resources/res-1/_unit_test_.pdf',
      );
    });

    test('canonical MIME is used even when the picker reports zip', () {
      expect(
        DojoResourceValidation.canonicalMimeType('slides.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        DojoResourceValidation.isSupported('slides.docx', 'application/zip'),
        isTrue,
      );
    });
  });

  group('resource upload service', () {
    test('upload creates Storage object then Firestore metadata', () async {
      final storage = _Storage();
      final store = _Store();
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(null),
        storage: storage,
        metadataStore: store,
      );

      final resource = await service.uploadResource(
        group: dojo,
        file: file('Electrostatics Notes.pdf'),
        uploaderName: 'Mayank',
      );

      expect(storage.uploadedPaths.single, resource.storagePath);
      expect(storage.uploadedMimeTypes.single, 'application/pdf');
      expect(store.created.single.id, resource.id);
      expect(resource.uploadedBy, 'me');
      expect(resource.uploadedByName, 'Mayank');
      expect(resource.name, 'Electrostatics Notes.pdf');
      expect(resource.storagePath, contains('dojos/dojo-1/resources/'));
      expect(
          storage.uploadedPaths.first, startsWith('dojos/dojo-1/resources/'));
    });

    test('DOCX uploads use canonical MIME instead of zip', () async {
      final storage = _Storage();
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(null),
        storage: storage,
        metadataStore: _Store(),
      );

      final resource = await service.uploadResource(
        group: dojo,
        file: file('notes.docx', mimeType: 'application/zip'),
        uploaderName: 'Mayank',
      );

      expect(
        resource.mimeType,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(storage.uploadedMimeTypes.single, resource.mimeType);
    });

    test('Firestore failure cleans orphaned Storage object', () async {
      final storage = _Storage();
      final store = _Store()..failCreate = true;
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(null),
        storage: storage,
        metadataStore: store,
      );

      await expectLater(
        service.uploadResource(
          group: dojo,
          file: file('worksheet.pdf'),
          uploaderName: 'Mayank',
        ),
        throwsA(isA<DojoResourceException>()),
      );

      expect(storage.deletedPaths, contains(storage.uploadedPaths.single));
    });

    test('unauthenticated and non-member uploads are blocked', () async {
      final signedOut = DojoResourceService(
        auth: _Auth(null),
        picker: _Picker(null),
        storage: _Storage(),
        metadataStore: _Store(),
      );
      await expectLater(
        signedOut.uploadResource(
          group: dojo,
          file: file('notes.pdf'),
          uploaderName: 'Student',
        ),
        throwsA(isA<DojoResourceException>()),
      );

      final outsider = DojoResourceService(
        auth: _Auth('outsider'),
        picker: _Picker(null),
        storage: _Storage(),
        metadataStore: _Store(),
      );
      await expectLater(
        outsider.uploadResource(
          group: dojo,
          file: file('notes.pdf'),
          uploaderName: 'Student',
        ),
        throwsA(isA<DojoResourceException>()),
      );
    });

    test('uploader can delete Storage and metadata', () async {
      final storage = _Storage();
      final store = _Store();
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(null),
        storage: storage,
        metadataStore: store,
      );
      final resource = _resource(uploadedBy: 'me');

      await service.deleteResource(group: dojo, resource: resource);

      expect(storage.deletedPaths, [resource.storagePath]);
      expect(store.deletedIds, [resource.id]);
    });

    test('unauthorized user cannot delete', () async {
      final service = DojoResourceService(
        auth: _Auth('friend'),
        picker: _Picker(null),
        storage: _Storage(),
        metadataStore: _Store(),
      );

      await expectLater(
        service.deleteResource(group: dojo, resource: _resource()),
        throwsA(isA<DojoResourceException>()),
      );
    });

    test('admin and owner can delete another member resource', () async {
      final adminStorage = _Storage();
      final adminStore = _Store();
      final adminService = DojoResourceService(
        auth: _Auth('owner'),
        picker: _Picker(null),
        storage: adminStorage,
        metadataStore: adminStore,
      );
      final resource = _resource(uploadedBy: 'me');

      await adminService.deleteResource(group: dojo, resource: resource);
      expect(adminStorage.deletedPaths, [resource.storagePath]);
      expect(adminStore.deletedIds, [resource.id]);

      final ownerOnly = dojo.copyWith(adminIds: const ['someone-else']);
      final ownerService = DojoResourceService(
        auth: _Auth('owner'),
        picker: _Picker(null),
        storage: _Storage(),
        metadataStore: _Store(),
      );
      await ownerService.deleteResource(group: ownerOnly, resource: resource);
    });
  });

  group('resources UI', () {
    testWidgets('Resources tab renders empty state and opens picker flow',
        (tester) async {
      final picker = _Picker(file('notes.pdf'));
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: picker,
        storage: _Storage(),
        metadataStore: _Store(),
      );

      await _show(
        tester,
        DojoResourcesTab(
          group: dojo,
          currentUserId: 'me',
          currentUserName: 'Mayank',
          service: service,
        ),
        const Size(320, 568),
      );

      expect(find.text('Nothing shared yet.'), findsOneWidget);
      await tester.tap(find.text('Upload Resource'));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('notes.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resource list renders newest first and long names fit',
        (tester) async {
      final store = _Store()
        ..resources.addAll([
          _resource(
            id: 'new',
            name:
                'A very long electrostatics notes file name that should ellipsize nicely.pdf',
            createdAt: DateTime(2026, 1, 2),
          ),
          _resource(id: 'old', name: 'Basics.pdf', createdAt: DateTime(2026)),
        ]);
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(null),
        storage: _Storage(),
        metadataStore: store,
      );

      await _show(
        tester,
        DojoResourcesTab(
          group: dojo,
          currentUserId: 'me',
          currentUserName: 'Mayank',
          service: service,
        ),
        const Size(412, 915),
      );

      expect(find.text('Resources'), findsOneWidget);
      expect(find.byType(ResourceCard), findsNWidgets(2));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip('Add resource'), findsOneWidget);
      final cards =
          tester.widgetList<ResourceCard>(find.byType(ResourceCard)).toList();
      expect(cards.first.resource.id, 'new');
      expect(cards.last.resource.id, 'old');
      expect(find.textContaining('A very long electrostatics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long filenames and empty state fit a small phone',
        (tester) async {
      await _show(
        tester,
        DojoResourcesTab(
          group: dojo,
          currentUserId: 'me',
          currentUserName: 'Mayank',
          service: DojoResourceService(
            auth: _Auth('me'),
            picker: _Picker(null),
            storage: _Storage(),
            metadataStore: _Store(),
          ),
        ),
        const Size(320, 568),
      );

      expect(find.text('Nothing shared yet.'), findsOneWidget);
      expect(
        find.text('Upload notes, worksheets, or presentations for your Dojo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('duplicate upload taps are ignored', (tester) async {
      final picker = _DelayedPicker(file('notes.pdf'));
      final storage = _Storage()..holdUpload = true;
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: picker,
        storage: storage,
        metadataStore: _Store(),
      );

      await _show(
        tester,
        DojoResourcesTab(
          group: dojo,
          currentUserId: 'me',
          currentUserName: 'Mayank',
          service: service,
        ),
        const Size(320, 568),
      );

      await tester.tap(find.text('Upload Resource'));
      await tester.tap(find.text('Upload Resource'));
      await tester.pump();
      expect(picker.calls, 1);

      picker.complete();
      await tester.pumpAndSettle();
      final uploadButton = find.byType(SenseiPrimaryButton).last;
      await tester.tap(uploadButton);
      await tester.pump();
      await tester.tap(uploadButton);
      await tester.pump();
      expect(storage.uploadCalls, 1);
      storage.releaseUpload();
      await tester.pumpAndSettle();
    });

    testWidgets('upload progress and friendly error render', (tester) async {
      final storage = _Storage()
        ..holdUpload = true
        ..failUpload = true;
      final service = DojoResourceService(
        auth: _Auth('me'),
        picker: _Picker(file('notes.pdf')),
        storage: storage,
        metadataStore: _Store(),
      );

      await _show(
        tester,
        DojoResourcesTab(
          group: dojo,
          currentUserId: 'me',
          currentUserName: 'Mayank',
          service: service,
        ),
        const Size(320, 568),
      );

      await tester.tap(find.text('Upload Resource'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      storage.releaseUpload();
      await tester.pumpAndSettle();
      expect(find.text("Couldn't upload this resource. Try again."),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _show(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: child)),
  );
  await tester.pumpAndSettle();
}

DojoResource _resource({
  String id = 'resource-1',
  String name = 'Electrostatics Notes.pdf',
  String uploadedBy = 'owner',
  DateTime? createdAt,
}) {
  return DojoResource(
    id: id,
    dojoId: 'dojo-1',
    name: name,
    storagePath: 'dojos/dojo-1/resources/$id/$name',
    downloadUrl: 'https://example.com/$name',
    mimeType: 'application/pdf',
    extension: 'pdf',
    sizeBytes: 2400000,
    uploadedBy: uploadedBy,
    uploadedByName: 'Mayank',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

class _Auth implements DojoResourceAuth {
  final String? uid;

  _Auth(this.uid);

  @override
  Future<DojoResourceUser?> currentUser() async {
    if (uid == null) return null;
    return DojoResourceUser(uid: uid!);
  }
}

class _Picker implements DojoResourcePicker {
  final DojoResourceFile? file;
  int calls = 0;

  _Picker(this.file);

  @override
  Future<DojoResourceFile?> pickResource() async {
    calls++;
    return file;
  }
}

class _DelayedPicker implements DojoResourcePicker {
  final DojoResourceFile? file;
  final Completer<DojoResourceFile?> _completer = Completer();
  int calls = 0;

  _DelayedPicker(this.file);

  void complete() {
    if (!_completer.isCompleted) _completer.complete(file);
  }

  @override
  Future<DojoResourceFile?> pickResource() {
    calls++;
    return _completer.future;
  }
}

class _Storage implements DojoResourceStorage {
  final uploadedPaths = <String>[];
  final uploadedMimeTypes = <String>[];
  final deletedPaths = <String>[];
  bool failUpload = false;
  bool holdUpload = false;
  int uploadCalls = 0;
  Completer<void>? _hold;

  void releaseUpload() {
    final hold = _hold;
    if (hold != null && !hold.isCompleted) hold.complete();
  }

  @override
  Future<String> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    required String uploadedBy,
    void Function(DojoResourceUploadProgress progress)? onProgress,
  }) async {
    uploadCalls++;
    uploadedPaths.add(storagePath);
    uploadedMimeTypes.add(mimeType);
    onProgress?.call(const DojoResourceUploadProgress(
      transferredBytes: 512,
      totalBytes: 1024,
    ));
    if (holdUpload) {
      _hold = Completer<void>();
      await _hold!.future;
    }
    if (failUpload) {
      throw const DojoResourceException(DojoResourceErrorCode.uploadFailed);
    }
    return 'https://example.com/$storagePath';
  }

  @override
  Future<void> delete(String storagePath) async {
    deletedPaths.add(storagePath);
  }
}

class _Store implements DojoResourceMetadataStore {
  final resources = <DojoResource>[];
  final created = <DojoResource>[];
  final deletedIds = <String>[];
  bool failCreate = false;

  @override
  Stream<List<DojoResource>> watchResources(String dojoId) {
    final sorted = List<DojoResource>.from(resources)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Stream.value(sorted);
  }

  @override
  Future<void> createResource(DojoResource resource) async {
    if (failCreate) throw StateError('metadata failed');
    created.add(resource);
    resources.add(resource);
  }

  @override
  Future<void> deleteResource(String dojoId, String resourceId) async {
    deletedIds.add(resourceId);
  }
}
