import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/common/widgets/sensei_bottom_navigation.dart';
import 'package:study_sensei/features/home/presentation/pages/home_screen.dart';

void main() {
  testWidgets('SenseiBottomNavigation renders 4 tabs correctly',
      (WidgetTester tester) async {
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          bottomNavigationBar: SenseiBottomNavigation(
            currentIndex: 0,
            onTap: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsNothing);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Sensei'), findsOneWidget);
    expect(find.text('Dojos'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Sensei'));
    expect(tappedIndex, 0);
    await tester.tap(find.text('Focus'));
    expect(tappedIndex, 1);

    await tester.tap(find.text('Dojos'));
    expect(tappedIndex, 2);

    await tester.tap(find.text('Profile'));
    expect(tappedIndex, 3);
  });

  testWidgets('HomeScreen renders hero and greeting in dark theme',
      (WidgetTester tester) async {
    // Set a phone screen resolution (e.g., iPhone 14: 390x844)
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify greeting and hero text
    expect(find.text('Stuck on something?'), findsOneWidget);
    expect(find.text('Take a photo. Get unstuck.'), findsOneWidget);
    expect(find.text("Keep going. You've got this."), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets('HomeScreen renders without overflow on small screen (320x568)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Stuck on something?'), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets('HomeScreen renders without overflow on large screen (412x915)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Stuck on something?'), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });
}
