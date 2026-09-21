import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/sensei_doubt_error.dart';

typedef ImageConverter = Future<Uint8List> Function(Uint8List bytes, int edge);

/// All transformations happen before selection. Upload never changes geometry.
class SenseiImagePreparation {
  static const maxBytes = 8 * 1024 * 1024;
  static const maxPixels = 32000000;
  final ImageConverter convert;
  final Future<int> Function(Uint8List) inspectPixels;
  SenseiImagePreparation(
      {ImageConverter? convert, Future<int> Function(Uint8List)? inspectPixels})
      : convert = convert ?? _convert,
        inspectPixels = inspectPixels ?? pixels;

  static Future<Uint8List> _convert(Uint8List bytes, int edge) async {
    // Decode at a bounded long edge before handing pixels to the native JPEG
    // encoder. The engine applies source orientation, including iOS HEIF.
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) => width >= height
          ? ui.TargetImageSize(width: math.min(width, edge))
          : ui.TargetImageSize(height: math.min(height, edge)),
    );
    ui.Image? image;
    Uint8List png;
    try {
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const SenseiDoubtError(DoubtErrorCode.mediaProcessingFailed);
      }
      png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec.dispose();
    }
    return FlutterImageCompress.compressWithList(png,
        minWidth: edge,
        minHeight: edge,
        quality: 92,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: false,
        keepExif: false);
  }

  static String? mimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  static bool isHeif(Uint8List bytes) {
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
      return false;
    }
    // Brand names, not the file extension, determine whether native conversion
    // can be attempted. Invalid containers fail with a controlled error.
    final brands =
        String.fromCharCodes(bytes.sublist(8, bytes.length.clamp(8, 64)));
    return ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1', 'heif']
        .any(brands.contains);
  }

  static Future<int> pixels(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return descriptor.width * descriptor.height;
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<XFile> prepare(XFile original) async {
    try {
      // Bound compressed input allocation before decoding any pixels.
      if (await original.length() > 64 * 1024 * 1024) {
        throw const SenseiDoubtError(DoubtErrorCode.mediaProcessingFailed);
      }
      final bytes = await original.readAsBytes();
      final supported = mimeType(bytes) != null;
      if (!supported && !isHeif(bytes)) {
        throw const SenseiDoubtError(DoubtErrorCode.imageUnreadable);
      }
      final sourcePixels = await inspectPixels(bytes);
      // Reject extreme sources before pixel decoding; ordinary 48 MP phone
      // photos can still be downsampled safely before selection.
      if (sourcePixels > 64000000) {
        throw const SenseiDoubtError(DoubtErrorCode.mediaProcessingFailed);
      }
      if (supported && bytes.length <= maxBytes && sourcePixels <= maxPixels) {
        return original;
      }
      // Native decoder downsamples and bakes orientation into JPEG pixels.
      // It does not upscale smaller sources. Try progressively smaller bounds
      // only when necessary to meet the server's encoded-size limit.
      for (final edge in [4096, 3072, 2048, 1536]) {
        final jpeg = await convert(bytes, edge);
        if (mimeType(jpeg) == 'image/jpeg' &&
            jpeg.length <= maxBytes &&
            await pixels(jpeg) <= maxPixels) {
          return XFile.fromData(jpeg,
              mimeType: 'image/jpeg', name: 'sensei.jpg');
        }
      }
      throw const SenseiDoubtError(DoubtErrorCode.mediaProcessingFailed);
    } on SenseiDoubtError {
      rethrow;
    } catch (_) {
      throw const SenseiDoubtError(DoubtErrorCode.mediaProcessingFailed);
    }
  }
}
