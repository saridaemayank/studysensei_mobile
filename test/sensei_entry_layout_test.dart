import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';
import 'package:study_sensei/features/sensei/screens/sensei_landing_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('One mirrored primary card at $size with text scale $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const SenseiLandingScreen()));
        final rectangles = <Rect>[];
        for (var i = 0; i < 1; i++) {
          final finder = find.byKey(ValueKey('sensei-action-$i'));
          rectangles.add(tester.getRect(finder));
        }

        expect(find.byType(SenseiCard), findsOneWidget);
        expect(
            find.textContaining(
                RegExp('Good morning|Good afternoon|Good evening')),
            findsOneWidget);
        expect(
            tester
                .widget<SenseiCard>(
                    find.byKey(const ValueKey('sensei-action-0')))
                .gradient,
            isNotNull);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
        expect(
            find.descendant(
                of: find.byKey(const ValueKey('sensei-action-0')),
                matching: find.byType(Text)),
            findsNWidgets(2));
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
        expect(find.bySemanticsLabel('Take Photo'), findsOneWidget);
        expect(find.text('Ask with Text'), findsNothing);
        await tester.tap(find.text('Explain'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 1; i++) {
          expect(tester.getRect(find.byKey(ValueKey('sensei-action-$i'))),
              rectangles[i]);
        }
        expect(find.byType(SenseiCard), findsOneWidget);
        expect(find.bySemanticsLabel('Record Video'), findsOneWidget);
        expect(find.text('Choose from Gallery'), findsNothing);
        expect(find.text('Describe Topic'), findsNothing);
        expect(find.bySemanticsLabel('Take Photo'), findsNothing);
        expect(find.byType(TextField), findsNothing);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Video card requests its required topic', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('Record Video'));
    await tester.tap(find.bySemanticsLabel('Record Video'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Continue'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Reflection');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Reflection');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });
}
