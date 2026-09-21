import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/features/focus/controllers/focus_timer_controller.dart';
import 'package:study_sensei/features/focus/services/focus_notifications.dart';
import 'package:study_sensei/features/focus/services/focus_session_storage.dart';

class MemoryStorage implements FocusSessionStorage {
  Map<String, dynamic>? value;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> state) async {
    if (fail) throw StateError('unavailable');
    value = state;
  }
}

class Alarms implements FocusNotifications {
  final scheduled = <DateTime>[];
  int cancellations = 0;
  bool denied = false;
  String? title;
  @override
  Future<void> requestPermission() async {
    if (denied) throw StateError('denied');
  }

  @override
  Future<void> schedule(DateTime end, String title, String body) async {
    scheduled.add(end);
    this.title = title;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

void main() {
  late DateTime now;
  late MemoryStorage storage;
  late Alarms alarms;
  late FocusTimerController timer;
  late int haptics;
  FocusTimerController create() => FocusTimerController(
      now: () => now,
      automaticTicks: false,
      storage: storage,
      notifications: alarms,
      onForegroundCompletion: () => haptics++);
  setUp(() {
    now = DateTime.utc(2026);
    storage = MemoryStorage();
    alarms = Alarms();
    haptics = 0;
    timer = create();
  });
  tearDown(() => timer.dispose());
  test(
      'start schedules one deadline; pause cancels; resume reschedules; reset cancels',
      () async {
    timer.start();
    timer.start();
    await timer.settled;
    expect(alarms.scheduled, [now.add(const Duration(minutes: 25))]);
    now = now.add(const Duration(seconds: 12));
    timer.pause();
    await timer.settled;
    expect(storage.value!['remainingMs'], 1488000);
    expect(alarms.cancellations, 1);
    now = now.add(const Duration(hours: 1));
    timer.resume();
    await timer.settled;
    expect(alarms.scheduled.last, now.add(const Duration(seconds: 1488)));
    timer.reset();
    await timer.settled;
    expect(alarms.cancellations, 2);
    expect(timer.remainingSeconds, 1500);
  });
  test('background resume jumps to clock and expired target completes once',
      () async {
    timer.start();
    await timer.settled;
    timer.setForeground(false);
    now = now.add(const Duration(minutes: 2));
    timer.setForeground(true);
    expect(timer.remainingSeconds, 1380);
    expect(timer.clockRevision, 1);
    timer.setForeground(false);
    now = now.add(const Duration(hours: 1));
    timer.setForeground(true);
    timer.refresh();
    await timer.settled;
    expect(timer.status, FocusSessionStatus.completed);
    expect(haptics, 1);
    expect(alarms.scheduled.length, 1);
    expect(alarms.cancellations, 1);
    expect(timer.progress, 1);
  });
  test('running session survives process recreation with original deadline',
      () async {
    timer.start();
    await timer.settled;
    final deadline = timer.targetEndTime;
    timer.dispose();
    now = now.add(const Duration(minutes: 2));
    timer = create();
    await timer.restore();
    await timer.settled;
    expect(timer.targetEndTime, deadline);
    expect(timer.remainingSeconds, 1380);
    expect(timer.progress, closeTo(2 / 25, .0001));
    expect(timer.clockRevision, 1);
  });
  test(
      'paused session and custom duration survive restart without elapsed countdown',
      () async {
    timer.selectDuration(const Duration(minutes: 90));
    timer.start();
    now = now.add(const Duration(seconds: 45));
    timer.pause();
    await timer.settled;
    timer.dispose();
    now = now.add(const Duration(days: 2));
    timer = create();
    await timer.restore();
    expect(timer.isPaused, true);
    expect(timer.remainingSeconds, 5355);
    expect(timer.selectedDuration.inMinutes, 90);
    expect(timer.targetEndTime, isNull);
  });
  test('expired restored session completes without replay or completion haptic',
      () async {
    timer.start();
    await timer.settled;
    timer.dispose();
    now = now.add(const Duration(hours: 1));
    timer = create();
    await timer.restore();
    await timer.settled;
    expect(timer.status, FocusSessionStatus.completed);
    expect(timer.remainingSeconds, 0);
    expect(haptics, 0);
    expect(alarms.scheduled.length, 1);
    timer.dispose();
    timer = create();
    await timer.restore();
    expect(timer.status, FocusSessionStatus.completed);
  });
  test('permission and storage failures cannot stop countdown', () async {
    alarms.denied = true;
    storage.fail = true;
    timer.start();
    await timer.settled;
    now = now.add(const Duration(minutes: 1));
    timer.refresh();
    expect(timer.remainingSeconds, 1440);
    expect(timer.isRunning, true);
  });
  test('rapid start pause resume reset cannot leave stale notification',
      () async {
    timer.start();
    timer.pause();
    timer.resume();
    timer.reset();
    await timer.settled;
    expect(alarms.scheduled, isEmpty);
    expect(alarms.cancellations, 1);
    expect(storage.value!['status'], 'setup');
  });
  test('break presets persist and use distinct notification copy', () async {
    timer.selectSessionType(FocusSessionType.shortBreak);
    timer.start();
    await timer.settled;
    expect(timer.remainingSeconds, 300);
    expect(alarms.title, 'Short break complete');
    now = now.add(const Duration(minutes: 5));
    timer.refresh();
    await timer.settled;
    expect(timer.status, FocusSessionStatus.completed);
    expect(haptics, 1);
    timer.reset();
    timer.selectSessionType(FocusSessionType.longBreak);
    timer.start();
    await timer.settled;
    expect(timer.remainingSeconds, 900);
    expect(alarms.title, 'Long break complete');
    expect(storage.value!['type'], 'longBreak');
  });
  test('progress stays bounded after clock adjustments', () {
    timer.start();
    now = now.subtract(const Duration(hours: 1));
    timer.refresh();
    expect(timer.progress, 0);
    expect(timer.remainingSeconds, 1500);
    now = now.add(const Duration(days: 1));
    timer.refresh();
    expect(timer.progress, 1);
  });
  test('malformed storage falls back safely', () async {
    storage.value = {'version': 999};
    await timer.restore();
    expect(timer.status, FocusSessionStatus.setup);
  });
}
