import 'package:study_sensei/features/sensei/screens/doubt_processing_screen.dart';
import 'package:study_sensei/features/sensei/screens/sensei_image_flow.dart';
import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/home/presentation/pages/home_screen.dart';
import 'package:study_sensei/features/sensei/screens/camera_screen.dart';
import 'package:study_sensei/features/sensei/screens/select_area_screen.dart';
import 'package:study_sensei/features/sensei/screens/sensei_landing_screen.dart';
import 'camera_screen_test.dart' show TestCameraPlatform, back;
import 'select_area_screen_test.dart' show fixtureImage, waitForImage;

class FlowCameraPlatform extends TestCameraPlatform {
  final XFile image = fixtureImage('portrait');
  @override
  Future<List<CameraDescription>> availableCameras() async => [back];
  @override
  Future<XFile> takePicture(int cameraId) async => image;
}

class FlowImagePicker extends ImagePickerPlatform {
  XFile? image = fixtureImage('landscape');
  int calls = 0;
  Completer<XFile?>? pending;
  @override
  Future<XFile?> getImageFromSource(
      {required ImageSource source,
      ImagePickerOptions options = const ImagePickerOptions()}) async {
    calls++;
    expectSync(source, ImageSource.gallery);
    expectSync(options.maxWidth, 2048);
    expectSync(options.maxHeight, 2048);
    return pending?.future ?? Future.value(image);
  }
}

void main() {
  late FlowCameraPlatform camera;
  late FlowImagePicker picker;
  setUp(() {
    final originalCamera = CameraPlatform.instance;
    final originalPicker = ImagePickerPlatform.instance;
    camera = FlowCameraPlatform();
    picker = FlowImagePicker();
    CameraPlatform.instance = camera;
    ImagePickerPlatform.instance = picker;
    addTearDown(() {
      CameraPlatform.instance = originalCamera;
      ImagePickerPlatform.instance = originalPicker;
    });
  });

  Future<void> entry(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('Entry camera capture opens Select Area and releases camera',
      (tester) async {
    await entry(tester);
    await tester.tap(find.bySemanticsLabel('Take Photo'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await waitForImage(tester);
    expect(find.byType(SelectAreaScreen), findsOneWidget);
    expect(tester.widget<SelectAreaScreen>(find.byType(SelectAreaScreen)).image,
        same(camera.image));
    expect(camera.disposed, [1]);
    await tester.tap(find.text('Use full image'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What do you need?'), findsOneWidget);
    await tester.tap(find.text('Explain this'));
    await tester.pump();
    await tester.tap(find.text('Get Help'));
    await tester.pumpAndSettle();
    expect(find.byType(DoubtProcessingScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectAreaScreen), findsOneWidget);
    expect(tester.widget<SelectAreaScreen>(find.byType(SelectAreaScreen)).image,
        same(camera.image));
  });

  testWidgets('Shared gallery helper opens Select Area', (tester) async {
    picker.pending = Completer<XFile?>();
    await entry(tester);
    final flow = SenseiImageFlow.chooseFromGallery(
        tester.element(find.byType(SenseiLandingScreen)));
    picker.pending!.complete(picker.image);
    await waitForImage(tester);
    expect(picker.calls, 1);
    expect(find.byType(SelectAreaScreen), findsOneWidget);
    expect(tester.widget<SelectAreaScreen>(find.byType(SelectAreaScreen)).image,
        same(picker.image));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SenseiLandingScreen), findsOneWidget);
    await flow;
  });

  testWidgets('Gallery cancellation stays on Entry', (tester) async {
    picker.image = null;
    await entry(tester);
    await SenseiImageFlow.chooseFromGallery(
        tester.element(find.byType(SenseiLandingScreen)));
    await tester.pumpAndSettle();
    expect(find.byType(SelectAreaScreen), findsNothing);
    expect(find.byType(SenseiLandingScreen), findsOneWidget);
  });

  testWidgets('Camera gallery shortcut also enters Select Area',
      (tester) async {
    await entry(tester);
    await tester.tap(find.bySemanticsLabel('Take Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose from Gallery'));
    await waitForImage(tester);
    expect(find.byType(SelectAreaScreen), findsOneWidget);
    expect(tester.widget<SelectAreaScreen>(find.byType(SelectAreaScreen)).image,
        same(picker.image));
    expect(camera.disposed, [1]);
  });

  testWidgets('Home camera shortcut consumes its photo result too',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stuck on something?'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await waitForImage(tester);
    expect(find.byType(SelectAreaScreen), findsOneWidget);
  });
}
