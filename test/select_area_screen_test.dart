import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_request.dart';
import 'package:study_sensei/features/sensei/screens/select_area_screen.dart';
import 'package:study_sensei/features/sensei/widgets/focus_region_editor.dart';

XFile fixtureImage(String name) =>
    XFile.fromData(File('test/fixtures/$name.png').readAsBytesSync(),
        name: '$name.png');

Future<void> waitForImage(WidgetTester tester) async {
  // Engine decoding completes outside the fake clock; wait for actual readiness.
  await tester.runAsync(() async {
    for (var i = 0; i < 100; i++) {
      await tester.pump();
      if (find.byType(FocusRegionEditor).evaluate().isNotEmpty ||
          find.text("Couldn't open this image.").evaluate().isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  Finder continueButton() => find.widgetWithText(ElevatedButton, 'Continue');
  bool canContinue(WidgetTester tester) =>
      tester.widget<ElevatedButton>(continueButton()).onPressed != null;

  Future<void> show(WidgetTester tester, String image, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: SelectAreaScreen(image: fixtureImage(image))));
    await waitForImage(tester);
  }

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    for (final image in ['portrait', 'landscape', 'tall', 'wide']) {
      testWidgets('$image image fits $size and full image enables Continue',
          (tester) async {
        await show(tester, image, size);
        expect(find.byType(FocusRegionEditor), findsOneWidget);
        expect(canContinue(tester), isFalse);
        final imageBounds =
            tester.getRect(find.byKey(const ValueKey('selection-image')));
        final canvas =
            tester.getRect(find.byKey(const ValueKey('selection-canvas')));
        expect(imageBounds.left, greaterThanOrEqualTo(canvas.left));
        expect(imageBounds.right, lessThanOrEqualTo(canvas.right + .001));
        expect(imageBounds.top, greaterThanOrEqualTo(canvas.top));
        expect(imageBounds.bottom, lessThanOrEqualTo(canvas.bottom + .001));
        expect(tester.getRect(continueButton()).bottom,
            lessThanOrEqualTo(size.height - 34));
        await tester.tap(find.text('Use full image'));
        await tester.pump();
        expect(canContinue(tester), isTrue);
        expect(find.text('Using full image'), findsOneWidget);
        expect(
            tester
                .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
                .region!
                .isFullImage,
            isTrue);
        await tester.tap(find.byTooltip('Reset selection'));
        await tester.pump();
        expect(canContinue(tester), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'Letterbox drag is ignored; create, move and resize stay inside image',
      (tester) async {
    await show(tester, 'landscape', const Size(412, 915));
    final bounds =
        tester.getRect(find.byKey(const ValueKey('selection-image')));
    final canvas =
        tester.getRect(find.byKey(const ValueKey('selection-canvas')));
    await tester.dragFrom(
        Offset(canvas.center.dx, canvas.top + 2), const Offset(25, 20));
    await tester.pump();
    expect(canContinue(tester), isFalse);
    final start =
        bounds.topLeft + Offset(bounds.width * .25, bounds.height * .25);
    await tester.dragFrom(start, Offset(bounds.width * .5, bounds.height * .5));
    await tester.pump();
    var region = tester
        .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
        .region!;
    expect(region.x, closeTo(.25, .001));
    expect(region.y, closeTo(.25, .001));
    expect(region.width, closeTo(.5, .001));
    expect(canContinue(tester), isTrue);
    await tester.dragFrom(bounds.center, const Offset(1000, 1000));
    await tester.pump();
    region = tester
        .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
        .region!;
    expect(region.x + region.width, closeTo(1, .001));
    expect(region.y + region.height, closeTo(1, .001));
    final rect = region.toDisplayRect(bounds.size).shift(bounds.topLeft);
    await tester.dragFrom(rect.topLeft, const Offset(-1000, -1000));
    await tester.pump();
    region = tester
        .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
        .region!;
    expect(region.x, 0);
    expect(region.y, 0);
    expect(region.isFullImage, isTrue);
    // Full-image mode can immediately be replaced by a smaller selection.
    await tester.dragFrom(start, const Offset(80, 60));
    await tester.pump();
    expect(
        tester
            .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
            .region!
            .isFullImage,
        isFalse);
  });

  testWidgets('Selection survives viewport changes', (tester) async {
    await show(tester, 'portrait', const Size(320, 568));
    final bounds =
        tester.getRect(find.byKey(const ValueKey('selection-image')));
    await tester.dragFrom(
        bounds.topLeft + const Offset(40, 40), const Offset(80, 80));
    await tester.pump();
    final before = tester
        .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
        .region!;
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();
    final after = tester
        .widget<FocusRegionEditor>(find.byType(FocusRegionEditor))
        .region!;
    expect([after.x, after.y, after.width, after.height],
        [before.x, before.y, before.width, before.height]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small layout keeps actions accessible at larger text size',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: SelectAreaScreen(image: fixtureImage('portrait'))));
    await waitForImage(tester);
    await tester.tap(find.text('Use full image'));
    await tester.pump();
    expect(canContinue(tester), isTrue);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(continueButton()).bottom, lessThanOrEqualTo(534));
  });

  testWidgets('Help request retains original XFile and normalized region',
      (tester) async {
    final image = fixtureImage('portrait');
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.darkTheme,
        home: const Text('Entry')));
    final result = navigator.currentState!.push<SenseiHelpRequest>(
        MaterialPageRoute(builder: (_) => SelectAreaScreen(image: image)));
    await waitForImage(tester);
    await tester.tap(find.text('Use full image'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explain this'));
    await tester.pump();
    await tester.tap(find.text('Get Help'));
    await tester.pumpAndSettle();
    final selection = (await result)!.imageSelection;
    expect(identical(selection.image, image), isTrue);
    expect(selection.focusRegion.isFullImage, isTrue);
    expect(await image.readAsBytes(),
        File('test/fixtures/portrait.png').readAsBytesSync());
    expect(find.text('Entry'), findsOneWidget);
  });

  testWidgets('Image read failure is clean and retry recovers', (tester) async {
    final image = RetryImage();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: SelectAreaScreen(image: image)));
    await waitForImage(tester);
    expect(find.text("Couldn't open this image."), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);
    expect(canContinue(tester), isFalse);
    image.fail = false;
    await tester.tap(find.text('Try Again'));
    await waitForImage(tester);
    expect(find.byType(FocusRegionEditor), findsOneWidget);
  });
}

class RetryImage extends XFile {
  RetryImage() : super('unused');
  bool fail = true;
  @override
  Future<Uint8List> readAsBytes() async {
    if (fail) throw StateError('private details');
    return File('test/fixtures/portrait.png').readAsBytesSync();
  }
}
