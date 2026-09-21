import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class DojoResource extends Equatable {
  final String id;
  final String dojoId;
  final String name;
  final String storagePath;
  final String downloadUrl;
  final String mimeType;
  final String extension;
  final int sizeBytes;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime createdAt;
  final String? originalFileName;

  const DojoResource({
    required this.id,
    required this.dojoId,
    required this.name,
    required this.storagePath,
    required this.downloadUrl,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
    this.originalFileName,
  });

  Map<String, dynamic> toFirestore({bool useServerTimestamp = false}) => {
        'name': name,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'mimeType': mimeType,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        'createdAt':
            useServerTimestamp ? FieldValue.serverTimestamp() : createdAt,
        if (originalFileName != null) 'originalFileName': originalFileName,
      };

  factory DojoResource.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String dojoId,
  ) {
    final data = doc.data() ?? {};
    final createdAtRaw = data['createdAt'];
    final createdAt = switch (createdAtRaw) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String value => DateTime.tryParse(value) ?? DateTime.now(),
      _ => DateTime.now(),
    };

    return DojoResource(
      id: doc.id,
      dojoId: dojoId,
      name: data['name']?.toString() ?? 'Untitled resource',
      storagePath: data['storagePath']?.toString() ?? '',
      downloadUrl: data['downloadUrl']?.toString() ?? '',
      mimeType: data['mimeType']?.toString() ?? 'application/octet-stream',
      extension: data['extension']?.toString() ?? '',
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
      uploadedBy: data['uploadedBy']?.toString() ?? '',
      uploadedByName: data['uploadedByName']?.toString() ?? 'Dojo member',
      createdAt: createdAt,
      originalFileName: data['originalFileName']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        dojoId,
        name,
        storagePath,
        downloadUrl,
        mimeType,
        extension,
        sizeBytes,
        uploadedBy,
        uploadedByName,
        createdAt,
        originalFileName,
      ];
}
