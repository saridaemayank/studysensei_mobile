import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/focus/controllers/focus_timer_controller.dart';
import 'package:study_sensei/features/focus/screens/focus_screen.dart';
import 'package:study_sensei/features/focus/widgets/flip_clock.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';
import 'package:study_sensei/features/common/widgets/sensei_bottom_navigation.dart';

Future<void> showFocus(WidgetTester tester, FocusTimerController timer,
    {Size size = const Size(412, 915), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!),
      home: FocusScreen(controller: timer)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Break presets share scene and completion controls',
      (tester) async {
    final timer = FocusTimerController(automaticTicks: false);
    addTearDown(timer.dispose);
    await showFocus(tester, timer, size: const Size(320, 568), scale: 2);
    await tester.ensureVisible(find.text('Short Break').first);
    await tester.tap(find.text('Short Break').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Break'));
    await tester.tap(find.text('Start Break'));
    await tester.pumpAndSettle();
    expect(timer.remainingSeconds, 300);
    expect(find.text('SHORT BREAK'), findsOneWidget);
    timer.finish();
    await tester.pumpAndSettle();
    expect(find.text('Break complete.'), findsOneWidget);
    expect(find.text('Ready when you are.'), findsOneWidget);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(timer.status, FocusSessionStatus.setup);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Resume replaces digits immediately and later ticks animate normally',
      (tester) async {
    var now = DateTime(2026);
    final timer = FocusTimerController(now: () => now, automaticTicks: false);
    addTearDown(timer.dispose);
    await showFocus(tester, timer);
    await tester.tap(find.text('Start Focus'));
    await tester.pumpAndSettle();
    final oldClock = tester.element(find.byType(FlipClock));
    timer.setForeground(false);
    now = now.add(const Duration(minutes: 2));
    timer.setForeground(true);
    await tester.pump();
    expect(tester.widget<FlipClock>(find.byType(FlipClock)).seconds, 1380);
    expect(identical(oldClock, tester.element(find.byType(FlipClock))), false);
    final currentClock = tester.element(find.byType(FlipClock));
    now = now.add(const Duration(seconds: 1));
    timer.refresh();
    await tester.pump();
    expect(
        identical(currentClock, tester.element(find.byType(FlipClock))), true);
  });
  testWidgets('Duration choices, default, and custom duration work',
      (tester) async {
    final timer = FocusTimerController(automaticTicks: false);
    addTearDown(timer.dispose);
    await showFocus(tester, timer);
    expect(timer.selectedDuration.inMinutes, 25);
    await tester.tap(find.text('45 min'));
    await tester.pump();
    expect(timer.selectedDuration.inMinutes, 45);
    await tester.tap(find.text('60 min'));
    await tester.pump();
    expect(timer.selectedDuration.inMinutes, 60);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(90);
    await tester.pump();
    await tester.tap(find.text('Use duration'));
    await tester.pumpAndSettle();
    expect(timer.selectedDuration.inMinutes, 90);
    expect(find.text('90 minutes'), findsOneWidget);
  });
  testWidgets('Start, pause, resume, reset and completion stay on one screen',
      (tester) async {
    var now = DateTime(2026);
    final timer = FocusTimerController(now: () => now, automaticTicks: false);
    addTearDown(timer.dispose);
    await showFocus(tester, timer);
    await tester.tap(find.text('Start Focus'));
    await tester.pumpAndSettle();
    expect(timer.isRunning, isTrue);
    expect(find.byType(FocusScreen), findsOneWidget);
    for (final name in ['sky', 'cloud', 'foreground']) {
      expect(find.byKey(ValueKey('focus-layer-$name')), findsOneWidget);
    }
    now = now.add(const Duration(seconds: 9));
    timer.refresh();
    await tester.pump();
    expect(tester.widget<FlipClock>(find.byType(FlipClock)).seconds, 1491);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    now = now.add(const Duration(minutes: 5));
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(timer.remainingSeconds, 1491);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(timer.remainingSeconds, 1500);
    await tester.tap(find.text('Start Focus'));
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 25));
    timer.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Focus complete.'), findsOneWidget);
    expect(timer.remainingSeconds, 0);
    await tester.tap(find.text('Start Again'));
    await tester.pumpAndSettle();
    expect(timer.isRunning, isTrue);
    expect(timer.remainingSeconds, 1500);
  });
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Setup and active states fit $size at $scale text',
          (tester) async {
        final timer = FocusTimerController(automaticTicks: false);
        addTearDown(timer.dispose);
        await showFocus(tester, timer, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Start Focus'));
        await tester.tap(find.text('Start Focus'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Pause'));
        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('End Session'));
        expect(find.text('Resume'), findsOneWidget);
        timer.finish();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Switching tabs preserves the running timer', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const MainLayout()));
    Finder tab(String text) => find.descendant(
        of: find.byType(SenseiBottomNavigation), matching: find.text(text));
    await tester.tap(tab('Focus'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Focus'));
    await tester.tap(find.text('Start Focus'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SenseiBottomNavigation), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(tab('Focus'));
    await tester.pump();
    expect(find.text('FOCUS SESSION'), findsOneWidget);
    expect(find.text('Pause').hitTestable(), findsOneWidget);
    expect(tester.widget<FlipClock>(find.byType(FlipClock)).seconds,
        lessThanOrEqualTo(1500));
    expect(find.byType(SenseiBottomNavigation), findsNothing);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.byType(SenseiBottomNavigation), findsNothing);
    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();
    expect(find.byType(SenseiBottomNavigation), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Countdown starts during the entry animation and has one readable label',
      (tester) async {
    var now = DateTime(2026);
    final timer = FocusTimerController(now: () => now, automaticTicks: false);
    addTearDown(timer.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: FocusScreen(controller: timer)));
    await tester.ensureVisible(find.text('Start Focus'));
    await tester.tap(find.text('Start Focus'));
    expect(timer.isRunning, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    now = now.add(const Duration(seconds: 2));
    timer.refresh();
    await tester.pump(const Duration(milliseconds: 500));
    expect(timer.remainingSeconds, 1498);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('24 minutes 58 seconds remaining'),
        findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Flip clock animates only changed digits', (tester) async {
    Widget app(int seconds) => MaterialApp(
        home: Scaffold(
            body: SizedBox(width: 300, child: FlipClock(seconds: seconds))));
    await tester.pumpWidget(app(1509));
    expect(find.byType(FlipDigit), findsNWidgets(4));
    await tester.pumpWidget(app(1508));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('focus-digit-0')),
            matching: find.byType(Transform)),
        findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('focus-digit-3')),
            matching: find.byType(Transform)),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(app(180 * 60));
    expect(find.byType(FlipDigit), findsNWidgets(5));
  });
}
