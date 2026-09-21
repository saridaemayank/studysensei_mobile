import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/exam_dojo_group.dart';
import '../../data/models/exam_dojo_daily_block.dart';
import '../../data/models/exam_dojo_subject.dart';
import '../../data/repositories/exam_dojo_repository.dart';
import '../../services/exam_dojo_logger.dart';

class ExamDojoController extends ChangeNotifier {
  ExamDojoController({
    required this.userId,
    ExamDojoRepository? repository,
  }) : _repository = repository ?? ExamDojoRepository() {
    _subscribe();
  }

  final String userId;
  final ExamDojoRepository _repository;
  StreamSubscription<ExamDojoGroup?>? _subscription;

  ExamDojoGroup? _dojo;
  bool _isLoading = true;
  String? _errorMessage;
  List<ExamDojoDailyBlock> _dailyBlocks = [];
  bool _isBlocksLoading = false;
  String? _blocksError;
  String? _blocksDateKey;
  Map<String, double> _subjectProgressById = const <String, double>{};
  Map<String, double> _subjectProgressByName = const <String, double>{};
  double _myProgressRatio = 0;
  double _groupProgressRatio = 0;
  bool _hasGroupProgress = false;
  bool _isProgressLoading = false;

  ExamDojoGroup? get dojo => _dojo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ExamDojoDailyBlock> get dailyBlocks => _dailyBlocks;
  bool get isBlocksLoading => _isBlocksLoading;
  String? get blocksError => _blocksError;
  Map<String, double> get subjectProgressById => _subjectProgressById;
  Map<String, double> get subjectProgressByName => _subjectProgressByName;
  double get myProgressRatio => _myProgressRatio;
  double get groupProgressRatio => _groupProgressRatio;
  bool get isProgressLoading => _isProgressLoading;
  bool get hasGroupProgress => _hasGroupProgress;

  void _subscribe() {
    _subscription?.cancel();
    _isLoading = true;
    ExamDojoLogger.log(
      'controller.stream.subscribe',
      details: {'userId': userId},
    );
    _subscription = _repository.streamActiveDojo(userId).listen(
      (dojo) {
        _dojo = dojo;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        if (_dojo != null) {
          _refreshProgress();
        }
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> ensureDailyBlocks({DateTime? date}) async {
    if (_dojo == null) {
      ExamDojoLogger.log(
        'controller.ensureDailyBlocks.skipNoDojo',
        details: {'userId': userId},
      );
      return;
    }
    final now = date ?? DateTime.now();
    final dateKey = _formatDateKey(now);
    ExamDojoLogger.log(
      'controller.ensureDailyBlocks.start',
      details: {'userId': userId, 'dojoId': _dojo!.id, 'date': dateKey},
    );
    if (_blocksDateKey == dateKey) {
      ExamDojoLogger.log(
        'controller.ensureDailyBlocks.cached',
        details: {'userId': userId, 'dojoId': _dojo!.id, 'date': dateKey},
      );
      return;
    }
    if (_isBlocksLoading) return;
    _isBlocksLoading = true;
    _blocksError = null;
    _blocksDateKey = dateKey;
    notifyListeners();

    try {
      final existing = await _repository.fetchStoredBlocks(
        userId: userId,
        dojoId: _dojo!.id,
        date: now,
      );
      if (existing.isNotEmpty) {
        ExamDojoLogger.log(
          'controller.ensureDailyBlocks.existing',
          details: {
            'userId': userId,
            'dojoId': _dojo!.id,
            'date': dateKey,
            'count': existing.length,
          },
        );
        _dailyBlocks = existing;
      } else {
        final generated = await _repository.generateDailyBlocks(
          dojoId: _dojo!.id,
          date: now,
        );
        if (generated.isNotEmpty) {
          ExamDojoLogger.log(
            'controller.ensureDailyBlocks.generated',
            details: {
              'userId': userId,
              'dojoId': _dojo!.id,
              'date': dateKey,
              'count': generated.length,
            },
          );
          _dailyBlocks = generated;
        } else {
          _dailyBlocks = await _repository.fetchStoredBlocks(
            userId: userId,
            dojoId: _dojo!.id,
            date: now,
          );
        }
      }
    } catch (e) {
      _blocksError = e.toString();
      ExamDojoLogger.log(
        'controller.ensureDailyBlocks.error',
        details: {
          'userId': userId,
          'dojoId': _dojo!.id,
          'date': dateKey,
          'message': _blocksError,
        },
      );
    } finally {
      _isBlocksLoading = false;
      ExamDojoLogger.log(
        'controller.ensureDailyBlocks.complete',
        details: {
          'userId': userId,
          'dojoId': _dojo!.id,
          'date': dateKey,
          'count': _dailyBlocks.length,
          'error': _blocksError,
        },
      );
      notifyListeners();
    }
  }

  Future<void> retryDailyBlocks() async {
    ExamDojoLogger.log(
      'controller.ensureDailyBlocks.retry',
      details: {'userId': userId, 'dojoId': _dojo?.id},
    );
    _blocksDateKey = null;
    await ensureDailyBlocks();
    await _refreshProgress();
  }

  Future<void> generateRoadmap({
    required DateTime studyWindowStart,
    required DateTime studyWindowEnd,
    required int weeklyLoadMinutes,
    String? notes,
  }) async {
    if (_dojo == null) return;
    await _repository.generateRoadmap(
      dojoId: _dojo!.id,
      studyWindowStart: studyWindowStart,
      studyWindowEnd: studyWindowEnd,
      weeklyLoadMinutes: weeklyLoadMinutes,
      notes: notes,
    );
  }

  Future<void> createDojo({
    required String name,
    String? description,
    required List<ExamDojoSubject> subjects,
    List<String>? memberIds,
  }) async {
    if (_dojo != null) {
      throw StateError('An active Exam Dojo already exists.');
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    ExamDojoLogger.log(
      'controller.createDojo.start',
      details: {
        'name': name,
        'subjectCount': subjects.length,
        'chaptersPerSubject': subjects
            .map((s) => {'subject': s.name, 'chapters': s.chapters})
            .toList(),
      },
    );
    try {
      _dojo = await _repository.createDojo(
        userId: userId,
        name: name,
        description: description,
        subjects: subjects,
        memberIds: memberIds,
      );
      ExamDojoLogger.log(
        'controller.createDojo.success',
        details: {'dojoId': _dojo?.id},
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      ExamDojoLogger.log(
        'controller.createDojo.error',
        details: {'message': _errorMessage},
      );
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> refreshProgress() => _refreshProgress();

  Future<void> _refreshProgress() async {
    if (_dojo == null) return;
    if (_isProgressLoading) return;
    _isProgressLoading = true;
    notifyListeners();
    try {
      final summary = await _repository.fetchSubjectProgress(
        userId: userId,
        dojoId: _dojo!.id,
      );
      final byId = <String, double>{};
      final byName = <String, double>{};
      for (final stat in summary.subjects) {
        final ratio = stat.ratio;
        if (stat.subjectId != null && stat.subjectId!.isNotEmpty) {
          byId[stat.subjectId!] = ratio;
        }
        byName[stat.subjectName] = ratio;
      }
      _subjectProgressById = byId;
      _subjectProgressByName = byName;
      _myProgressRatio = summary.overallRatio;
      _groupProgressRatio = 0;
      _hasGroupProgress = false;
      ExamDojoLogger.log(
        'controller.progress.success',
        details: {
          'userId': userId,
          'dojoId': _dojo!.id,
          'subjects': summary.subjects.length,
          'overall': _myProgressRatio,
        },
      );
    } catch (error) {
      ExamDojoLogger.log(
        'controller.progress.error',
        details: {
          'userId': userId,
          'dojoId': _dojo?.id,
          'message': error.toString(),
        },
      );
    } finally {
      _isProgressLoading = false;
      notifyListeners();
    }
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
