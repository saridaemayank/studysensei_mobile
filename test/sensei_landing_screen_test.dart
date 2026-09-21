import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/auth/models/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/sensei/screens/sensei_landing_screen.dart';

class _NamedUserProvider extends ChangeNotifier implements UserProvider {
  @override
  User? get user => null;
  @override
  bool get isAuthenticated => false;
  @override
  UserPreferences get userPreferences => UserPreferences(name: 'Mayank Sharma');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Greeting gives the profile name prominence without header icons',
      (tester) async {
    final profile = _NamedUserProvider();
    addTearDown(profile.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
      value: profile,
      child: MaterialApp(
          theme: AppTheme.darkTheme, home: const SenseiLandingScreen()),
    ));
    final name =
        tester.widget<Text>(find.byKey(const ValueKey('sensei-user-name')));
    expect(name.data, 'Mayank');
    expect(name.style!.fontSize, 36);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
  testWidgets('SenseiLandingScreen renders the reference capture card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SenseiLandingScreen(),
      ),
    );
    await tester.pump();

    // Verify main copy
    expect(find.text("Stuck on something?"), findsOneWidget);
    expect(
      find.text("Take a photo. Get unstuck."),
      findsOneWidget,
    );

    // Verify the single capture action
    expect(find.bySemanticsLabel('Take Photo'), findsOneWidget);

    expect(find.text('Choose from Gallery'), findsNothing);

    expect(find.text('Ask with Text'), findsNothing);

    // Verify the greeting copy
    expect(
      find.text('“Keep going. You’ve got this.”'),
      findsOneWidget,
    );

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets('Landing has no duplicate gallery or text actions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const SenseiLandingScreen()));
    expect(find.bySemanticsLabel('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsNothing);
    expect(find.text('Ask with Text'), findsNothing);
  });

  testWidgets(
      'SenseiLandingScreen renders without overflow on small screen (320x568)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SenseiLandingScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text("Stuck on something?"), findsOneWidget);
    expect(find.bySemanticsLabel('Take Photo'), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets(
      'SenseiLandingScreen renders without overflow on large screen (412x915)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SenseiLandingScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text("Stuck on something?"), findsOneWidget);
    expect(find.bySemanticsLabel('Take Photo'), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });
}
