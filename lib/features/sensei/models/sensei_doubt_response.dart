import 'package:flutter/foundation.dart';
import 'sensei_help_mode.dart';
import 'sensei_doubt_error.dart';

enum DoubtInputStatus {
  readable('readable'),
  unreadable('unreadable'),
  emptyRegion('empty_region'),
  missingContext('missing_context'),
  unsupported('unsupported');

  const DoubtInputStatus(this.apiValue);
  final String apiValue;
}

enum DoubtWorkStatus {
  correct('correct'),
  mistakeFound('mistake_found'),
  incomplete('incomplete'),
  unclear('unclear');

  const DoubtWorkStatus(this.apiValue);
  final String apiValue;
}

enum DoubtMistakeType {
  conceptual,
  formula,
  algebra,
  arithmetic,
  assumption,
  notation,
  other,
  none
}

@immutable
class SenseiDoubtResponse {
  final int version;
  final SenseiHelpMode mode;
  final String subject, topic, title, explanation;
  final double confidence;
  final DoubtInputStatus inputStatus;
  final String? concept, keyIdea, nextAction, mistake, correctedStep, hint;
  final DoubtWorkStatus? workStatus;
  final DoubtMistakeType? mistakeType;
  final int? hintLevel;
  const SenseiDoubtResponse._(
      {required this.version,
      required this.mode,
      required this.subject,
      required this.topic,
      required this.title,
      required this.explanation,
      required this.confidence,
      required this.inputStatus,
      this.concept,
      this.keyIdea,
      this.nextAction,
      this.mistake,
      this.correctedStep,
      this.hint,
      this.workStatus,
      this.mistakeType,
      this.hintLevel});

  factory SenseiDoubtResponse.fromJson(Object? value) {
    const invalid = SenseiDoubtError(DoubtErrorCode.malformedResponse);
    if (value is! Map<String, dynamic>) {
      throw invalid;
    }
    if (value['version'] is! int) {
      throw invalid;
    }
    if (value['version'] != 1) {
      throw const SenseiDoubtError(DoubtErrorCode.unsupportedVersion);
    }
    String? string(String key, {bool nullable = false}) {
      if (!value.containsKey(key)) {
        throw invalid;
      }
      final v = value[key];
      if (v == null && nullable) {
        return null;
      }
      if (v is! String || v.trim().isEmpty || v.length > 8000) {
        throw invalid;
      }
      return v;
    }

    try {
      final confidence = value['confidence'];
      if (confidence is! num ||
          !confidence.isFinite ||
          confidence < 0 ||
          confidence > 1) {
        throw invalid;
      }
      final subject = string('subject')!;
      if (!['Physics', 'Chemistry', 'Mathematics', 'Biology', 'Other']
          .contains(subject)) {
        throw invalid;
      }
      final work = string('workStatus', nullable: true);
      final mistake = string('mistakeType', nullable: true);
      if (!value.containsKey('hintLevel') ||
          (value['hintLevel'] != null && value['hintLevel'] != 1)) {
        throw invalid;
      }
      final result = SenseiDoubtResponse._(
        version: 1,
        mode: SenseiHelpMode.values
            .firstWhere((m) => m.apiValue == string('mode')),
        subject: subject,
        topic: string('topic')!,
        title: string('title')!,
        explanation: string('explanation')!,
        confidence: confidence.toDouble(),
        inputStatus: DoubtInputStatus.values
            .firstWhere((s) => s.apiValue == string('inputStatus')),
        concept: string('concept', nullable: true),
        keyIdea: string('keyIdea', nullable: true),
        nextAction: string('nextAction', nullable: true),
        mistake: string('mistake', nullable: true),
        correctedStep: string('correctedStep', nullable: true),
        hint: string('hint', nullable: true),
        workStatus: work == null
            ? null
            : DoubtWorkStatus.values.firstWhere((s) => s.apiValue == work),
        mistakeType:
            mistake == null ? null : DoubtMistakeType.values.byName(mistake),
        hintLevel: value['hintLevel'] as int?,
      );
      if (result.inputStatus != DoubtInputStatus.readable &&
          (result.nextAction == null || result.confidence > .5)) {
        throw invalid;
      }
      if (result.mode == SenseiHelpMode.checkWork) {
        if (result.workStatus == null ||
            result.mistakeType == null ||
            result.nextAction == null ||
            result.concept != null ||
            result.keyIdea != null ||
            result.hint != null ||
            result.hintLevel != null) {
          throw invalid;
        }
        if (result.workStatus == DoubtWorkStatus.mistakeFound) {
          if (result.inputStatus != DoubtInputStatus.readable ||
              result.mistake == null ||
              result.correctedStep == null ||
              result.mistakeType == DoubtMistakeType.none) {
            throw invalid;
          }
        } else if (result.mistake != null ||
            result.correctedStep != null ||
            result.mistakeType != DoubtMistakeType.none) {
          throw invalid;
        }
        if (result.inputStatus != DoubtInputStatus.readable &&
            result.workStatus != DoubtWorkStatus.unclear) {
          throw invalid;
        }
      } else {
        if (result.workStatus != null ||
            result.mistake != null ||
            result.mistakeType != null ||
            result.correctedStep != null) {
          throw invalid;
        }
        if (result.mode == SenseiHelpMode.hint) {
          if (result.hintLevel != 1 ||
              result.hint == null ||
              result.concept != null ||
              result.keyIdea != null) {
            throw invalid;
          }
        } else if (result.hint != null ||
            result.hintLevel != null ||
            (result.inputStatus == DoubtInputStatus.readable &&
                (result.concept == null ||
                    result.keyIdea == null ||
                    result.nextAction == null))) {
          throw invalid;
        }
      }
      return result;
    } on SenseiDoubtError {
      rethrow;
    } catch (_) {
      throw invalid;
    }
  }
}
