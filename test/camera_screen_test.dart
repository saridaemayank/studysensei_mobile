import 'dart:async';
// Camera's platform boundary is faked; no physical camera is emulated.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/sensei/screens/camera_screen.dart';

const back = CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90);
const front = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 90);

class TestCameraPlatform extends CameraPlatform {
  int created = 0;
  final disposed = <int>[];
  final flashes = <FlashMode>[];
  String? failure;
  Completer<XFile>? capture;
  int captures = 0;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<int> createCameraWithSettings(
      CameraDescription description, MediaSettings settings) async {
    expectSync(settings.enableAudio, isFalse);
    if (failure != null) {
      throw CameraException(failure!, 'private device details');
    }
    return ++created;
  }

  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(
          cameraId, 1280, 720, ExposureMode.auto, true, FocusMode.auto, true));
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    flashes.add(mode);
  }

  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(key: ValueKey('preview'), color: Colors.grey);
  @override
  Future<void> dispose(int cameraId) async {
    disposed.add(cameraId);
  }

  @override
  Future<XFile> takePicture(int cameraId) {
    captures++;
    return capture?.future ?? Future.value(XFile('/tmp/photo.jpg'));
  }
}

void main() {
  late TestCameraPlatform platform;
  setUp(() {
    final original = CameraPlatform.instance;
    platform = TestCameraPlatform();
    CameraPlatform.instance = platform;
    addTearDown(() => CameraPlatform.instance = original);
  });

  Future<void> showCamera(WidgetTester tester,
      {List<CameraDescription> cameras = const [back],
      ValueChanged<XFile>? onPhoto}) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: CameraScreen(
            subject: 'General',
            concept: 'Doubt',
            availableCamerasOverride: cameras,
            onPhotoCaptured: onPhoto)));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('Preview and controls fit $size with safe areas',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);
      await showCamera(tester);
      expect(find.text('Point at your doubt'), findsOneWidget);
      expect(find.text('You can select the exact part next.'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Flash Mode'), findsOneWidget);
      expect(find.bySemanticsLabel('Take photo'), findsOneWidget);
      expect(find.byIcon(Icons.flip_camera_ios_rounded), findsNothing);
      expect(tester.getTopLeft(find.text('Point at your doubt')).dy,
          greaterThan(100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(platform.disposed, [1]);
    });
  }

  testWidgets('Unavailable and denied camera can retry without raw errors',
      (tester) async {
    platform.failure = 'CameraAccessDenied';
    await showCamera(tester);
    expect(
        find.text('Camera access is needed to take a photo.'), findsOneWidget);
    platform.failure = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Point at your doubt'), findsOneWidget);
  });

  testWidgets('No cameras leaves gallery and close available', (tester) async {
    await showCamera(tester, cameras: []);
    expect(find.text("Camera isn't available right now."), findsOneWidget);
    expect(find.byTooltip('Choose from Gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resume recreates once and camera switch resets flash',
      (tester) async {
    await showCamera(tester, cameras: [back, front]);
    await tester.tap(find.byTooltip('Flash Mode'));
    await tester.pumpAndSettle();
    expect(platform.flashes.last, FlashMode.auto);
    await tester.tap(find.byTooltip('Switch Camera'));
    await tester.pumpAndSettle();
    expect(platform.flashes.last, FlashMode.off);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(platform.created, 3);
    expect(platform.disposed, [1, 2]);
    expect(find.text('Point at your doubt'), findsOneWidget);
  });

  testWidgets('Repeated shutter taps deliver once and release camera',
      (tester) async {
    platform.capture = Completer<XFile>();
    final photos = <XFile>[];
    await showCamera(tester, onPhoto: photos.add);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.tap(find.bySemanticsLabel('Take photo'));
    expect(platform.captures, 1);
    platform.capture!.complete(XFile('/tmp/photo.jpg'));
    await tester.pumpAndSettle();
    expect(photos.single.path, '/tmp/photo.jpg');
    expect(platform.disposed, [1]);
  });

  testWidgets('Capture failure permits retry', (tester) async {
    platform.capture = Completer<XFile>();
    await showCamera(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    platform.capture!.completeError(CameraException('capture', 'private'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't take the photo. Try again."), findsOneWidget);
    expect(platform.captures, 1);
  });
  testWidgets('Closing during capture does not navigate again', (tester) async {
    platform.capture = Completer<XFile>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('Entry')));
    final result = navigator.currentState!.push<XFile>(MaterialPageRoute(
        builder: (_) => const CameraScreen(
            subject: 'General',
            concept: 'Doubt',
            availableCamerasOverride: [back])));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    platform.capture!.complete(XFile('/tmp/late.jpg'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(find.text('Entry'), findsOneWidget);
    expect(platform.disposed, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Capture returns the existing XFile route result',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('Entry')));
    final result = navigator.currentState!.push<XFile>(MaterialPageRoute(
        builder: (_) => const CameraScreen(
            subject: 'General',
            concept: 'Doubt',
            availableCamerasOverride: [back])));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    expect((await result)!.path, '/tmp/photo.jpg');
    expect(platform.disposed, [1]);
  });
}
