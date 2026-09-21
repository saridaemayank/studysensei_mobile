import 'dart:ui' show Tristate;
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';
import 'package:study_sensei/features/common/widgets/sensei_bottom_navigation.dart';
import 'package:study_sensei/features/focus/screens/focus_screen.dart';
import 'package:study_sensei/features/routes/app_routes.dart';
import 'package:study_sensei/features/sensei/models/sensei_mode.dart';
import 'package:study_sensei/features/sensei/screens/sensei_landing_screen.dart';
import 'package:study_sensei/features/sensei/screens/sensei_capture_screen.dart';
import 'package:study_sensei/features/sensei/screens/sensei_review_screen.dart';
import 'package:study_sensei/features/sensei/widgets/sensei_mode_switch.dart';
import 'camera_screen_test.dart' show TestCameraPlatform, back;

class ExplainCameraPlatform extends TestCameraPlatform {
  bool? audioEnabled;
  @override
  Future<List<CameraDescription>> availableCameras() async => [back];
  @override
  Future<int> createCameraWithSettings(
      CameraDescription description, MediaSettings settings) async {
    audioEnabled = settings.enableAudio;
    return ++created;
  }
}

void main() {
  testWidgets('Shell starts on Sensei, new nav order, Focus setup is available',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const MainLayout()));
    expect(
        tester
            .widget<SenseiBottomNavigation>(find.byType(SenseiBottomNavigation))
            .currentIndex,
        0);
    expect(SenseiBottomNavigation.items.map((item) => item.label),
        ['Sensei', 'Focus', 'Dojos', 'Profile']);
    expect(find.text('Stuck on something?'), findsOneWidget);
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusScreen), findsOneWidget);
    expect(find.text('How long do you want to lock in?'), findsOneWidget);
    // Returning to the first tab keeps its mode state.
    await tester.tap(find.descendant(
        of: find.byType(SenseiBottomNavigation),
        matching: find.text('Sensei')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(SenseiBottomNavigation),
        matching: find.text('Sensei')));
    await tester.pumpAndSettle();
    expect(tester.widget<SenseiModeSwitch>(find.byType(SenseiModeSwitch)).value,
        SenseiMode.explain);
  });

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('Both modes fit $size with safe areas', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
      expect(
          tester.widget<SenseiModeSwitch>(find.byType(SenseiModeSwitch)).value,
          SenseiMode.doubt);
      expect(find.bySemanticsLabel('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsNothing);
      expect(find.text('Ask with Text'), findsNothing);
      await tester.tap(find.text('Explain'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Curious about something?'), findsOneWidget);
      expect(find.bySemanticsLabel('Take Photo'), findsNothing);
      expect(find.text('Describe Topic'), findsNothing);
      expect(find.bySemanticsLabel('Record Video'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsNothing);
      expect(find.text('Ask with Text'), findsNothing);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Mode switch exposes selected semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Doubt'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Explain'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Doubt'))
              .flagsCollection
              .isSelected,
          Tristate.isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'Explain Record Video enters original capture with topic and audio',
      (tester) async {
    final original = CameraPlatform.instance;
    final camera = ExplainCameraPlatform();
    CameraPlatform.instance = camera;
    addTearDown(() => CameraPlatform.instance = original);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('Record Video'));
    await tester.tap(find.bySemanticsLabel('Record Video'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reflection');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final capture =
        tester.widget<SenseiCaptureScreen>(find.byType(SenseiCaptureScreen));
    expect(capture.concept, 'Reflection');
    expect(camera.audioEnabled, isTrue);
  });

  testWidgets('Explain entry has only the video action', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Record Video'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsNothing);
    expect(find.text('Describe Topic'), findsNothing);
  });

  testWidgets('Legacy review route receives original video fields',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppRoutes.senseiReview,
      onGenerateInitialRoutes: (_) => [
        AppRoutes.generateRoute(
            const RouteSettings(name: AppRoutes.senseiReview, arguments: {
          'subject': 'Physics',
          'concept': 'Reflection',
          'videoUrl': 'https://example.test/video.mp4',
          'duration': 12
        }))
      ],
    ));
    final review =
        tester.widget<SenseiReviewScreen>(find.byType(SenseiReviewScreen));
    expect(review.concept, 'Reflection');
    expect(review.videoUrl, 'https://example.test/video.mp4');
    expect(review.duration, 12);
  });

  testWidgets(
      'Tab routes preserve Sensei, Focus, Profile and Dojo destinations',
      (tester) async {
    for (final entry in {
      AppRoutes.sensei: 0,
      AppRoutes.focus: 1,
      AppRoutes.profile: 3,
      AppRoutes.assignments: 2
    }.entries) {
      await tester.pumpWidget(MaterialApp(
          key: ValueKey(entry.key),
          theme: AppTheme.darkTheme,
          onGenerateRoute: AppRoutes.generateRoute,
          initialRoute: entry.key));
      await tester.pumpAndSettle();
      expect(tester.widget<MainLayout>(find.byType(MainLayout)).initialIndex,
          entry.value);
    }
  });
}
