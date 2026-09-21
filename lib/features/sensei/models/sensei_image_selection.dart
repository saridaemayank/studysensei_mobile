import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'focus_region.dart';

/// Phase 5 input. The original file is retained without cropping or rewriting.
@immutable
class SenseiImageSelection {
  final XFile image;
  final FocusRegion focusRegion;

  const SenseiImageSelection({required this.image, required this.focusRegion});
}
