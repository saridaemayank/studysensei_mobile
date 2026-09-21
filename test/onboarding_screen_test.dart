import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/onboarding/data/onboarding_item.dart';
import 'package:study_sensei/features/onboarding/data/onboarding_storage.dart';
import 'package:study_sensei/features/onboarding/presentation/pages/onboarding_gate.dart';
import 'package:study_sensei/features/onboarding/presentation/pages/onboarding_screen.dart';

Widget _buildOnboardingApp({Widget? home}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: home,
    routes: {
      '/login': (_) => const Scaffold(body: Center(child: Text('LoginScreen'))),
      '/register': (_) =>
          const Scaffold(body: Center(child: Text('RegisterScreen'))),
    },
  );
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _buildOnboardingApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _goToFinalPage(WidgetTester tester) async {
  await tester.tap(find.text('Skip').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Returning signed-out users see auth choices without replay',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'study_sensei_onboarding_completed': true});
    await tester.pumpWidget(_buildOnboardingApp(
      home: OnboardingGate(
          completedBuilder: (_) =>
              const OnboardingScreen(showAuthChoices: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ready to begin?'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('LoginScreen'), findsOneWidget);
    expect(await const OnboardingStorage().getOnboardingCompleted(), isTrue);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding screen renders the first page', (tester) async {
    await _pumpOnboarding(tester);

    expect(find.text(onboardingItems.first.headline), findsOneWidget);
    expect(find.text(onboardingItems.first.description), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip'), findsWidgets);
  });

  testWidgets('continue advances through the swipe pages', (tester) async {
    await _pumpOnboarding(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text(onboardingItems[1].headline), findsOneWidget);
  });

  testWidgets('skip jumps to the final page', (tester) async {
    await _pumpOnboarding(tester);

    await _goToFinalPage(tester);

    expect(find.text(onboardingItems.last.headline), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('all five onboarding pages are reachable', (tester) async {
    await _pumpOnboarding(tester);

    for (var index = 1; index < onboardingItems.length; index++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text(onboardingItems[index].headline), findsOneWidget);
    }
  });

  testWidgets('Create Account saves the flag and routes to register',
      (tester) async {
    await _pumpOnboarding(tester);
    await _goToFinalPage(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(await OnboardingStorage.isCompleted(), isTrue);
    expect(find.text('RegisterScreen'), findsOneWidget);
  });

  testWidgets('Sign In saves the flag and routes to login', (tester) async {
    await _pumpOnboarding(tester);
    await _goToFinalPage(tester);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(await OnboardingStorage.isCompleted(), isTrue);
    expect(find.text('LoginScreen'), findsOneWidget);
  });

  testWidgets('startup gate shows onboarding when the flag is false',
      (tester) async {
    await tester.pumpWidget(
      _buildOnboardingApp(
        home: OnboardingGate(
          completedBuilder: (_) => const Text('Existing auth route'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(onboardingItems.first.headline), findsOneWidget);
    expect(find.text('Existing auth route'), findsNothing);
  });

  testWidgets('startup gate skips onboarding when the flag is true',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      OnboardingStorage.completedKey: true,
    });

    await tester.pumpWidget(
      _buildOnboardingApp(
        home: OnboardingGate(
          completedBuilder: (_) => const Text('Existing auth route'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing auth route'), findsOneWidget);
    expect(find.text(onboardingItems.first.headline), findsNothing);
  });

  testWidgets('onboarding layout has no overflow at 320x568', (tester) async {
    await _pumpOnboarding(tester, size: const Size(320, 568), textScale: 1.2);

    expect(find.text(onboardingItems.first.headline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding layout has no overflow at 412x915', (tester) async {
    await _pumpOnboarding(tester, size: const Size(412, 915), textScale: 1.4);

    expect(find.text(onboardingItems.first.headline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
