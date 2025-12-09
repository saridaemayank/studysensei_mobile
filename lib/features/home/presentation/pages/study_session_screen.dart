import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_lock_provider.dart';

import '../../data/models/home_assignment.dart';
import '../../data/models/study_block.dart';
import '../../data/repositories/home_repository.dart';
import '../../data/repositories/study_session_repository.dart';
import '../../services/study_session_notification_service.dart';

class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({
    super.key,
    this.assignment,
    this.studyBlock,
    this.durationMinutesOverride,
  }) : assert(assignment != null || studyBlock != null);

  final HomeAssignment? assignment;
  final StudyBlock? studyBlock;
  final int? durationMinutesOverride;

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen>
    with WidgetsBindingObserver {
  late final StudySessionRepository _sessionRepository;
  late final HomeRepository _homeRepository;
  late final String _userId;
  late final DateTime _startedAt;
  late Duration _plannedDuration;
  late final String? _linkedMilestoneId;
  late final String? _linkedMilestoneGoalId;

  Duration _elapsed = Duration.zero;
  Duration _elapsedBeforePause = Duration.zero;
  DateTime? _resumeTimestamp;
  Timer? _timer;

  bool _isPaused = false;
  bool _appInForeground = true;
  bool _notificationVisible = false;
  String? _sessionId;
  bool _isSaving = false;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be authenticated to start a session');
    }
    _userId = user.uid;
    _sessionRepository = StudySessionRepository();
    _homeRepository = HomeRepository();
    _startedAt = DateTime.now();
    _linkedMilestoneId = widget.assignment?.milestoneId;
    _linkedMilestoneGoalId = widget.assignment?.goalId;
    final defaultDuration = widget.durationMinutesOverride ??
        widget.studyBlock?.durationMinutes ??
        widget.assignment?.estimatedMinutes ??
        25;
    _plannedDuration = Duration(minutes: max(defaultDuration, 1));
    _resumeTimestamp = DateTime.now();
    _startTimer();
    _createSession();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused || _resumeTimestamp == null) return;
      final elapsedSinceResume = DateTime.now().difference(_resumeTimestamp!);
      final updatedElapsed = _elapsedBeforePause + elapsedSinceResume;
      if (updatedElapsed >= _plannedDuration) {
        setState(() => _elapsed = _plannedDuration);
        _updateNotificationIfNeeded();
        unawaited(_handleAutoCompletion());
      } else {
        setState(() => _elapsed = updatedElapsed);
        _updateNotificationIfNeeded();
      }
    });
  }

  Future<void> _createSession() async {
    final existing = await _sessionRepository.findActiveSession(
      assignmentId: widget.assignment?.id,
      studyBlockId: widget.assignment == null ? widget.studyBlock?.id : null,
    );
    if (existing != null) {
      final existingData = existing.data() ?? {};
      final storedPlannedMinutes =
          (existingData['plannedDurationMinutes'] as int?) ??
              _plannedDuration.inMinutes;
      final storedActualMinutes =
          (existingData['actualDurationMinutes'] as int?) ?? 0;
      final normalizedPlanned =
          Duration(minutes: max(storedPlannedMinutes, 1));
      final clampedActualMinutes =
          storedActualMinutes.clamp(0, normalizedPlanned.inMinutes);
      final resumeElapsed = Duration(minutes: clampedActualMinutes);
      setState(() {
        _plannedDuration = normalizedPlanned;
        _elapsed = resumeElapsed;
        _elapsedBeforePause = resumeElapsed;
        _resumeTimestamp = DateTime.now();
        _sessionId = existing.id;
        _sessionEnded = false;
        _isPaused = false;
      });
      final progress = normalizedPlanned.inMinutes > 0
          ? clampedActualMinutes / normalizedPlanned.inMinutes
          : 0.0;
      await _sessionRepository.updateSession(existing.id, {
        'completionStatus': 'ongoing',
        'completionRatio': progress.clamp(0.0, 1.0),
        'endedAt': null,
      });
      await _linkSessionToMilestoneIfNeeded(existing.id);
      return;
    }

    final data = {
      'userId': _userId,
      'studyBlockId': widget.studyBlock?.id,
      'assignmentId': widget.assignment?.id,
      'goalId': widget.studyBlock?.goalId ?? widget.assignment?.goalId,
      'startedAt': Timestamp.fromDate(_startedAt),
      'plannedDurationMinutes': _plannedDuration.inMinutes,
      'actualDurationMinutes': 0,
      'completionStatus': 'ongoing',
      'completionRatio': 0.0,
      'endedAt': null,
    };
    final ref = await _sessionRepository.createSession(data);
    setState(() => _sessionId = ref.id);
    await _linkSessionToMilestoneIfNeeded(ref.id);
  }

  Future<void> _linkSessionToMilestoneIfNeeded(String sessionId) async {
    final milestoneId = _linkedMilestoneId;
    final goalId = _linkedMilestoneGoalId;
    if (milestoneId == null || goalId == null) return;
    try {
      await _homeRepository.appendLinkedSessionToMilestone(
        userId: _userId,
        goalId: goalId,
        milestoneId: milestoneId,
        sessionId: sessionId,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to link session $sessionId to milestone $milestoneId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dismissNotification();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      _dismissNotification();
    } else if (state == AppLifecycleState.paused) {
      _appInForeground = false;
      _updateNotificationIfNeeded();
    }
  }

  void _updateNotificationIfNeeded() {
    if (_appInForeground) {
      _dismissNotification();
      return;
    }
    final remaining = _plannedDuration - _elapsed;
    final remainingText = _formatDuration(
      remaining.isNegative ? Duration.zero : remaining,
    );
    StudySessionNotificationService.instance.showOngoingNotification(
      title: 'Ganbatte! Keep giving your best 🙌',
      body: 'Time left • $remainingText • Session in progress',
    );
    _notificationVisible = true;
  }

  void _dismissNotification() {
    if (_notificationVisible) {
      StudySessionNotificationService.instance.cancelNotification();
      _notificationVisible = false;
    }
  }

  Future<void> _notifyAppLockAboutCompletion(int actualMinutes) async {
    if (!mounted) return;
    try {
      final appLock = context.read<AppLockProvider>();
      final unlocked = await appLock.registerCompletedSession(actualMinutes);
      if (!unlocked && mounted) {
        final required = appLock.minimumSessionMinutes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Finish at least $required minutes to unlock other apps.',
            ),
          ),
        );
      }
    } catch (_) {
      // AppLockProvider is optional; ignore if it is not registered.
    }
  }

  Future<void> _confirmBeforeExit() async {
    if (_sessionEnded) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
            'Your session is still running. Do you want to stop and log your progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep studying'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop session'),
          ),
        ],
      ),
    );
    if (shouldStop == true) {
      await _handleStopSession();
    }
  }

  void _togglePause() {
    if (_isPaused) {
      _resumeTimestamp = DateTime.now();
      setState(() => _isPaused = false);
    } else {
      _elapsedBeforePause = _elapsed;
      _resumeTimestamp = null;
      setState(() => _isPaused = true);
    }
  }

  void _extendTime() {
    setState(() {
      _plannedDuration += const Duration(minutes: 10);
    });
    _updateNotificationIfNeeded();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session extended by 10 minutes')),
    );
  }

  Future<void> _handleAutoCompletion() async {
    if (_sessionEnded || _isSaving) return;
    _timer?.cancel();
    _dismissNotification();
    setState(() {
      _sessionEnded = true;
      _isSaving = true;
    });
    final endedAt = _startedAt.add(_plannedDuration);
    final actualMinutes = _plannedDuration.inMinutes;
    try {
      if (_sessionId != null) {
        await _sessionRepository.updateSession(_sessionId!, {
          'endedAt': Timestamp.fromDate(endedAt),
          'actualDurationMinutes': actualMinutes,
          'completionStatus': 'completed',
          'completionRatio': 1.0,
        });
        if (widget.studyBlock != null) {
          await _homeRepository.updateStudyBlock(
            userId: _userId,
            blockId: widget.studyBlock!.id,
            data: {'isCompleted': true},
          );
        }
        if (widget.assignment != null) {
          await _homeRepository.toggleAssignmentCompletion(
            userId: _userId,
            assignmentId: widget.assignment!.id,
            isCompleted: true,
          );
        }
      }
      unawaited(_notifyAppLockAboutCompletion(actualMinutes));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to auto-complete session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleStopSession() async {
    if (_sessionId == null || _isSaving) return;
    final result = await _showCompletionSheet();
    if (result == null) return;
    setState(() => _isSaving = true);
    _timer?.cancel();
    _dismissNotification();
    final endedAt = DateTime.now();
    final actualMinutes = max(_elapsed.inMinutes, 1);
    final qualifiesForAppLock = result.status == 'completed' || result.ratio >= 0.9;
    try {
      await _sessionRepository.updateSession(_sessionId!, {
        'endedAt': Timestamp.fromDate(endedAt),
        'actualDurationMinutes': actualMinutes,
        'completionStatus': result.status,
        'completionRatio': result.ratio,
      });
      if (widget.studyBlock != null && qualifiesForAppLock) {
        await _homeRepository.updateStudyBlock(
          userId: _userId,
          blockId: widget.studyBlock!.id,
          data: {'isCompleted': true},
        );
      }
      if (widget.assignment != null && result.markAssignmentComplete) {
        await _homeRepository.toggleAssignmentCompletion(
          userId: _userId,
          assignmentId: widget.assignment!.id,
          isCompleted: true,
        );
      }
      if (qualifiesForAppLock) {
        await _notifyAppLockAboutCompletion(actualMinutes);
      }
      setState(() {
        _sessionEnded = true;
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to end session: $e')),
        );
        _startTimer();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<_CompletionResult?> _showCompletionSheet() {
    CompletionChoice choice = CompletionChoice.completed;
    double ratio = 1.0;
    bool markAssignment = false;
    return showModalBottomSheet<_CompletionResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    'Did you complete this block?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: CompletionChoice.values
                        .map(
                          (option) => ChoiceChip(
                            label: Text(option.label),
                            selected: choice == option,
                            onSelected: (_) => setState(() {
                              choice = option;
                              if (choice == CompletionChoice.partial &&
                                  (ratio == 0 || ratio == 1)) {
                                ratio = 0.5;
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  if (choice == CompletionChoice.partial) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Select completion percentage',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [0.25, 0.5, 0.75].map((value) {
                        return ChoiceChip(
                          label: Text('${(value * 100).round()}%'),
                          selected: ratio == value,
                          onSelected: (_) => setState(() => ratio = value),
                        );
                      }).toList(),
                    ),
                  ],
                  if (widget.assignment != null) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: markAssignment,
                      onChanged: (value) =>
                          setState(() => markAssignment = value ?? false),
                      title: const Text('Mark assignment as completed?'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final status = choice.status;
                        Navigator.of(context).pop(
                          _CompletionResult(
                            status: status,
                            ratio: choice == CompletionChoice.partial
                                ? ratio
                                : (choice == CompletionChoice.completed ? 1.0 : 0.0),
                            markAssignmentComplete: markAssignment,
                          ),
                        );
                      },
                      child: const Text('Save session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.studyBlock?.title ?? widget.assignment?.title ?? 'Study Session';
    final subtitle = widget.studyBlock != null
        ? 'Study block · ${_plannedDuration.inMinutes} min'
        : widget.assignment != null
            ? 'Assignment · ${widget.assignment!.subject}'
            : null;
    final progress =
        (_elapsed.inSeconds / _plannedDuration.inSeconds).clamp(0.0, 1.0);

    return PopScope(
      canPop: _sessionEnded,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmBeforeExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Session'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress.toDouble(),
                          strokeWidth: 10,
                        ),
                      ),
                      Text(
                        _formatDuration(_elapsed),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Planned ${_plannedDuration.inMinutes} min',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: _togglePause,
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                  IconButton.filledTonal(
                    onPressed: _extendTime,
                    icon: const Icon(Icons.add_alarm),
                  ),
                  FilledButton(
                    onPressed: _isSaving ? null : _handleStopSession,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).abs().toString().padLeft(2, '0');
    final hours = duration.inHours;
    final seconds = duration.inSeconds.remainder(60).abs().toString().padLeft(2, '0');
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
}

class _CompletionResult {
  final String status;
  final double ratio;
  final bool markAssignmentComplete;

  _CompletionResult({
    required this.status,
    required this.ratio,
    required this.markAssignmentComplete,
  });
}

enum CompletionChoice { completed, partial, abandoned }

extension on CompletionChoice {
  String get label {
    switch (this) {
      case CompletionChoice.completed:
        return 'Completed';
      case CompletionChoice.partial:
        return 'Partial';
      case CompletionChoice.abandoned:
        return 'Abandoned';
    }
  }

  String get status {
    switch (this) {
      case CompletionChoice.completed:
        return 'completed';
      case CompletionChoice.partial:
        return 'partial';
      case CompletionChoice.abandoned:
        return 'abandoned';
    }
  }
}
