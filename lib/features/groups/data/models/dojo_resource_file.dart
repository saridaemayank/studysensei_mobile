import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class DojoResourceFile extends Equatable {
  final String name;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;

  const DojoResourceFile({
    required this.name,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  List<Object?> get props => [name, extension, mimeType, sizeBytes, bytes];
}
