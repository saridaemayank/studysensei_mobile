import 'package:flutter/foundation.dart';
import 'academic_level.dart';
import 'sensei_help_mode.dart';
import 'sensei_image_selection.dart';

/// Input for the future Processing flow; contains no generated content.
@immutable
class SenseiHelpRequest {
  final SenseiImageSelection imageSelection;
  final SenseiHelpMode mode;
  final AcademicLevel academicLevel;
  final String? userPrompt;

  const SenseiHelpRequest({
    required this.imageSelection,
    required this.mode,
    required this.academicLevel,
    this.userPrompt,
  });
}
