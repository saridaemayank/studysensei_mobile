import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/focus_notifications.dart';
import '../services/focus_session_storage.dart';

enum FocusSessionType { focus, shortBreak, longBreak }

extension FocusSessionTypeDetails on FocusSessionType {
  String get label => switch (this) {
        FocusSessionType.focus => 'Focus',
        FocusSessionType.shortBreak => 'Short Break',
        FocusSessionType.longBreak => 'Long Break',
      };
  int get minutes => switch (this) {
        FocusSessionType.focus => 25,
        FocusSessionType.shortBreak => 5,
        FocusSessionType.longBreak => 15,
      };
  String get notificationTitle => switch (this) {
        FocusSessionType.focus => 'Focus complete',
        FocusSessionType.shortBreak => 'Short break complete',
        FocusSessionType.longBreak => 'Long break complete',
      };
  String get notificationBody => switch (this) {
        FocusSessionType.focus => 'Nice work. Your session is done.',
        FocusSessionType.shortBreak => 'Ready to focus again?',
        FocusSessionType.longBreak => "Break’s over when you’re ready.",
      };
}

enum FocusSessionStatus { setup, running, paused, completed }

/// Wall-clock deadlines keep the session accurate when callbacks are suspended.
class FocusTimerController extends ChangeNotifier {
  final DateTime Function() _now;
  final bool automaticTicks;
  final FocusSessionStorage? storage;
  final FocusNotifications? notifications;
  final VoidCallback? onForegroundCompletion;
  Timer? _ticker;
  FocusSessionType sessionType = FocusSessionType.focus;
  DateTime? completedAt;
  bool foreground = true;
  bool _disposed = false;
  int clockRevision = 0;
  int _revision = 0;
  Future<void>? _restoration;
  Future<void> _writes = Future.value();
  Future<void> _alarms = Future.value();
  Future<void> get settled async {
    await _writes;
    await _alarms;
  }

  Future<void> _safe(Future<void> Function() action, String code) async {
    try {
      await action();
    } catch (_) {
      debugPrint('Focus: $code');
    }
  }

  Map<String, dynamic> get _snapshot => {
        'version': 1,
        'type': sessionType.name,
        'status': status.name,
        'durationMs': selectedDuration.inMilliseconds,
        'remainingMs': _remaining.inMilliseconds,
        'endMs': targetEndTime?.millisecondsSinceEpoch,
        'completedMs': completedAt?.millisecondsSinceEpoch,
      };

  void _save() {
    final snapshot = _snapshot;
    _writes = _writes.then((_) => _safe(() async {
          await storage?.write(snapshot);
        }, 'persistence_write_failed'));
  }

  void _sync({bool askPermission = false}) {
    final revision = ++_revision;
    _save();
    _alarms = _alarms.then((_) async {
      if (revision != _revision) return;
      // Permission is independent of countdown and storage. Recheck the state
      // after the OS prompt so a pause/reset cannot leave a stale alarm behind.
      if (askPermission) {
        await _safe(() async {
          await notifications?.requestPermission();
        }, 'notification_permission_unavailable');
      }
      if (revision != _revision) return;
      await _safe(() async {
        if (isRunning && targetEndTime!.isAfter(_now())) {
          await notifications?.schedule(targetEndTime!,
              sessionType.notificationTitle, sessionType.notificationBody);
        } else {
          await notifications?.cancel();
        }
      }, 'notification_unavailable');
    });
  }

  Future<void> restore() => _restoration ??= _restore();
  Future<void> _restore() async {
    final revision = _revision;
    await _safe(() async {
      final data = await storage?.read();
      if (_disposed || revision != _revision || data == null) return;
      if (data['version'] != 1) throw const FormatException();
      final type = FocusSessionType.values.byName(data['type'] as String);
      final savedStatus =
          FocusSessionStatus.values.byName(data['status'] as String);
      final duration = Duration(milliseconds: data['durationMs'] as int);
      final remaining = Duration(milliseconds: data['remainingMs'] as int);
      final end = data['endMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(data['endMs'] as int,
              isUtc: true);
      final completion = data['completedMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(data['completedMs'] as int,
              isUtc: true);
      if (duration.inMinutes < 5 ||
          duration > const Duration(minutes: 180) ||
          remaining < Duration.zero ||
          remaining > duration ||
          (savedStatus == FocusSessionStatus.running && end == null)) {
        throw const FormatException();
      }
      sessionType = type;
      selectedDuration = duration;
      _remaining =
          savedStatus == FocusSessionStatus.setup ? duration : remaining;
      targetEndTime = savedStatus == FocusSessionStatus.running ? end : null;
      completedAt = completion;
      status = savedStatus;
      clockRevision++;
      if (isRunning) {
        _remaining = end!.difference(_now());
        if (_remaining <= Duration.zero) {
          status = FocusSessionStatus.completed;
          completedAt = end;
          targetEndTime = null;
          _remaining = Duration.zero;
        } else if (_remaining > duration) {
          _remaining = duration;
        }
      }
      if (status == FocusSessionStatus.completed) _remaining = Duration.zero;
      _lastSeconds = remainingSeconds;
      if (isRunning) _schedule();
      _sync();
      notifyListeners();
    }, 'persistence_restore_failed');
  }

  void selectSessionType(FocusSessionType type) {
    if (status != FocusSessionStatus.setup) return;
    sessionType = type;
    selectDuration(Duration(minutes: type.minutes));
  }

  void setForeground(bool value) {
    if (foreground == value) return;
    foreground = value;
    if (!value) {
      _ticker?.cancel();
      refresh();
      _save();
    } else {
      clockRevision++;
      refresh();
      if (isRunning) _schedule();
      notifyListeners();
    }
  }

  Duration selectedDuration = const Duration(minutes: 25);
  Duration _remaining = const Duration(minutes: 25);
  DateTime? targetEndTime;
  FocusSessionStatus status = FocusSessionStatus.setup;
  int _lastSeconds = 1500;
  FocusTimerController(
      {DateTime Function()? now,
      this.automaticTicks = true,
      this.storage,
      this.notifications,
      this.onForegroundCompletion})
      : _now = now ?? DateTime.now;
  Duration get remainingDuration => _remaining;
  int get remainingSeconds =>
      (_remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();
  bool get isRunning => status == FocusSessionStatus.running;
  bool get isPaused => status == FocusSessionStatus.paused;
  double get progress =>
      (1 - _remaining.inMicroseconds / selectedDuration.inMicroseconds)
          .clamp(0, 1);

  void selectDuration(Duration duration) {
    if (status != FocusSessionStatus.setup) return;
    if (duration < const Duration(minutes: 5) ||
        duration > const Duration(minutes: 180)) {
      throw ArgumentError('Choose between 5 and 180 minutes.');
    }
    selectedDuration = duration;
    _remaining = duration;
    _lastSeconds = remainingSeconds;
    _sync();
    notifyListeners();
  }

  void _schedule() {
    _ticker?.cancel();
    if (automaticTicks && foreground) {
      _ticker =
          Timer.periodic(const Duration(milliseconds: 250), (_) => refresh());
    }
  }

  void start() {
    if (isRunning || isPaused) return;
    _remaining = selectedDuration;
    _lastSeconds = remainingSeconds;
    targetEndTime = _now().add(_remaining);
    status = FocusSessionStatus.running;
    completedAt = null;
    _schedule();
    _sync(askPermission: true);
    notifyListeners();
  }

  void refresh() {
    if (!isRunning) return;
    _remaining = targetEndTime!.difference(_now());
    if (_remaining > selectedDuration) _remaining = selectedDuration;
    if (_remaining <= Duration.zero) {
      finish();
      return;
    }
    if (remainingSeconds != _lastSeconds) {
      _lastSeconds = remainingSeconds;
      notifyListeners();
    }
  }

  void pause() {
    if (!isRunning) return;
    refresh();
    if (!isRunning) return;
    _ticker?.cancel();
    targetEndTime = null;
    status = FocusSessionStatus.paused;
    _sync();
    notifyListeners();
  }

  void resume() {
    if (!isPaused) return;
    targetEndTime = _now().add(_remaining);
    status = FocusSessionStatus.running;
    completedAt = null;
    _schedule();
    _sync(askPermission: true);
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    targetEndTime = null;
    _remaining = selectedDuration;
    _lastSeconds = remainingSeconds;
    status = FocusSessionStatus.setup;
    completedAt = null;
    _sync();
    notifyListeners();
  }

  void finish() {
    if (status == FocusSessionStatus.completed) return;
    _ticker?.cancel();
    completedAt = targetEndTime ?? _now();
    targetEndTime = null;
    _remaining = Duration.zero;
    _lastSeconds = 0;
    status = FocusSessionStatus.completed;
    _sync();
    if (foreground) {
      try {
        onForegroundCompletion?.call();
      } catch (_) {
        debugPrint('Focus: haptic_unavailable');
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
