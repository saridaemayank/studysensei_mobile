import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/features/focus/controllers/focus_timer_controller.dart';

void main() {
  late DateTime now;
  late FocusTimerController timer;
  setUp(() {
    now = DateTime(2026, 1, 1);
    timer = FocusTimerController(now: () => now, automaticTicks: false);
  });
  tearDown(() => timer.dispose());
  test('Defaults to 25 minutes and starts once', () {
    expect(timer.selectedDuration, const Duration(minutes: 25));
    timer.start();
    final end = timer.targetEndTime;
    now = now.add(const Duration(seconds: 7));
    timer.start();
    expect(timer.targetEndTime, end);
    timer.refresh();
    expect(timer.remainingSeconds, 1493);
  });
  test('Pause preserves fractional time and resume uses a fresh deadline', () {
    timer.start();
    now = now.add(const Duration(milliseconds: 2500));
    timer.pause();
    final remaining = timer.remainingDuration;
    now = now.add(const Duration(minutes: 10));
    timer.refresh();
    expect(timer.remainingDuration, remaining);
    timer.resume();
    expect(timer.targetEndTime, now.add(remaining));
    now = now.add(const Duration(seconds: 10));
    timer.refresh();
    expect(timer.remainingDuration, remaining - const Duration(seconds: 10));
  });
  test('Reset restores the selected duration', () {
    timer.selectDuration(const Duration(minutes: 45));
    timer.start();
    now = now.add(const Duration(minutes: 10));
    timer.refresh();
    timer.reset();
    expect(timer.status, FocusSessionStatus.setup);
    expect(timer.remainingSeconds, 2700);
    expect(timer.targetEndTime, isNull);
  });
  test('Sleep beyond deadline completes exactly once', () {
    timer.start();
    var changes = 0;
    timer.addListener(() => changes++);
    now = now.add(const Duration(hours: 2));
    timer.refresh();
    timer.refresh();
    expect(timer.remainingSeconds, 0);
    expect(timer.status, FocusSessionStatus.completed);
    expect(changes, 1);
    timer.start();
    expect(timer.remainingSeconds, 1500);
  });
  test('Duration bounds and active selection guard', () {
    expect(() => timer.selectDuration(const Duration(minutes: 4)),
        throwsArgumentError);
    expect(() => timer.selectDuration(const Duration(minutes: 181)),
        throwsArgumentError);
    timer.selectDuration(const Duration(minutes: 180));
    timer.start();
    timer.selectDuration(const Duration(minutes: 25));
    expect(timer.selectedDuration, const Duration(minutes: 180));
  });
}
