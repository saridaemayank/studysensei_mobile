import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/sensei/models/academic_level.dart';
import 'package:study_sensei/features/sensei/models/focus_region.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_mode.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_request.dart';
import 'package:study_sensei/features/sensei/models/sensei_image_selection.dart';
import 'package:study_sensei/features/sensei/screens/help_type_screen.dart';
import 'package:study_sensei/features/sensei/screens/select_area_screen.dart';
import 'package:study_sensei/features/sensei/widgets/focus_region_editor.dart';
import 'select_area_screen_test.dart' show fixtureImage, waitForImage;

void main() {
  SenseiImageSelection selection() => SenseiImageSelection(
      image: fixtureImage('portrait'),
      focusRegion: const FocusRegion(x: .2, y: .3, width: .5, height: .4));
  bool enabled(WidgetTester tester) =>
      tester
          .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Get Help'))
          .onPressed !=
      null;
  Finder card(SenseiHelpMode mode) =>
      find.bySemanticsLabel('${mode.displayTitle}. ${mode.description}');

  testWidgets(
      'Modes are exclusive and expose selected semantics; Boards defaults',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: HelpTypeScreen(imageSelection: selection())));
      for (final label in [
        'Explain this',
        'Check my work',
        'Give me a hint',
        'School',
        'Boards',
        'JEE',
        'Get Help'
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(enabled(tester), isFalse);
      await tester.ensureVisible(find.text('Boards'));
      await tester.pumpAndSettle();
      expect(
          tester
                  .getSemantics(find.bySemanticsLabel('Boards'))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue);
      for (final mode in SenseiHelpMode.values) {
        await tester.ensureVisible(find.text(mode.displayTitle));
        await tester.tap(find.text(mode.displayTitle));
        await tester.pump();
        expect(enabled(tester), isTrue);
        for (final other in SenseiHelpMode.values) {
          expect(
              tester.getSemantics(card(other)).flagsCollection.isSelected ==
                  Tristate.isTrue,
              other == mode);
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Get Help returns the same selection, chosen mode and level once',
      (tester) async {
    final input = selection();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.darkTheme,
        home: const Text('Caller')));
    final result = navigator.currentState!.push<SenseiHelpRequest>(
        MaterialPageRoute(
            builder: (_) => HelpTypeScreen(imageSelection: input)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check my work'));
    await tester.ensureVisible(find.text('JEE'));
    await tester.tap(find.text('JEE'));
    await tester.pump();
    final submit = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Get Help'))
        .onPressed!;
    submit();
    submit();
    await tester.pumpAndSettle();
    final request = (await result)!;
    expect(request.imageSelection, same(input));
    expect(request.imageSelection.image, same(input.image));
    expect(request.imageSelection.focusRegion, same(input.focusRegion));
    expect(request.mode, SenseiHelpMode.checkWork);
    expect(request.academicLevel, AcademicLevel.jee);
    expect(find.text('Caller'), findsOneWidget);
  });

  testWidgets('Explicit initial level is respected and can change to School',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: HelpTypeScreen(
              imageSelection: selection(),
              initialAcademicLevel: AcademicLevel.jee)));
      await tester.ensureVisible(find.text('JEE'));
      await tester.pumpAndSettle();
      expect(
          tester
                  .getSemantics(find.bySemanticsLabel('JEE'))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue);
      await tester.ensureVisible(find.text('School'));
      await tester.tap(find.text('School'));
      await tester.pump();
      expect(
          tester
                  .getSemantics(find.bySemanticsLabel('School'))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue);
      expect(
          tester
                  .getSemantics(find.bySemanticsLabel('JEE'))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isFalse);
    } finally {
      semantics.dispose();
    }
  });

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('Help Type fits $size with safe areas and reachable controls',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: HelpTypeScreen(imageSelection: selection())));
      for (final mode in SenseiHelpMode.values) {
        await tester.ensureVisible(find.text(mode.displayTitle));
        await tester.tap(find.text(mode.displayTitle));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('School'));
      await tester.tap(find.text('School'));
      await tester.pump();
      expect(enabled(tester), isTrue);
      final button =
          tester.getRect(find.widgetWithText(ElevatedButton, 'Get Help'));
      expect(button.bottom, lessThanOrEqualTo(size.height - 34));
      expect(button.top, greaterThan(44));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Back keeps Select Area state and decoded image alive',
      (tester) async {
    final image = fixtureImage('portrait');
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: SelectAreaScreen(image: image)));
    await waitForImage(tester);
    final bounds =
        tester.getRect(find.byKey(const ValueKey('selection-image')));
    await tester.dragFrom(
        bounds.topLeft + const Offset(50, 50), const Offset(100, 100));
    await tester.pump();
    final editor =
        tester.widget<FocusRegionEditor>(find.byType(FocusRegionEditor));
    final originalState = tester.state(find.byType(SelectAreaScreen));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final input = tester
        .widget<HelpTypeScreen>(find.byType(HelpTypeScreen))
        .imageSelection;
    expect(input.image, same(image));
    expect(input.focusRegion, same(editor.region));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final restored =
        tester.widget<FocusRegionEditor>(find.byType(FocusRegionEditor));
    expect(tester.state(find.byType(SelectAreaScreen)), same(originalState));
    expect(restored.image, same(editor.image));
    expect(restored.region, same(editor.region));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpTypeScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FocusRegionEditor), findsOneWidget);
  });
}
