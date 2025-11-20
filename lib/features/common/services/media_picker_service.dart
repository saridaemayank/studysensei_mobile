import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class PickedMedia {
  final Uint8List bytes;
  final String fileName;

  const PickedMedia({required this.bytes, required this.fileName});
}

/// Handles lightweight media selection without requiring storage permissions.
class MediaPickerService {
  MediaPickerService() {
    _ensureAndroidPhotoPicker();
  }

  final ImagePicker _picker = ImagePicker();

  Future<PickedMedia?> pickProfilePhoto() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
      maxWidth: 2048,
    );
    if (file == null) return null;

    return PickedMedia(
      bytes: await file.readAsBytes(),
      fileName: file.name,
    );
  }

  void _ensureAndroidPhotoPicker() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final ImagePickerPlatform platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) {
      platform.useAndroidPhotoPicker = true;
    }
  }
}
