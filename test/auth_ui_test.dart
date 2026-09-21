import 'dart:async';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_sensei/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/auth/register/screens/register_screen.dart';
import 'package:study_sensei/features/auth/register/screens/subject_selection_screen.dart';
import 'package:study_sensei/features/auth/presentation/pages/phone_verification_screen.dart';

class _FirebaseApp extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
        CoreInitializeResponse(
            name: '[DEFAULT]',
            options: CoreFirebaseOptions(
                apiKey: '123',
                appId: '123',
                messagingSenderId: '123',
                projectId: '123',
                storageBucket: 'test.appspot.com'),
            pluginConstants: {}),
      ];
}

class _LoginProvider extends UserProvider {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> signInWithEmailAndPassword(String email, String password) {
    calls++;
    return completion.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FirebaseApp());
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Future<void> show(WidgetTester tester, Widget screen, Size size, double scale,
      {double keyboard = 0}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!),
        home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Onboarding signup switches to login without popping or stacking',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const OnboardingScreen(showAuthChoices: true),
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/login': (_) => const LoginScreen(),
      },
    ));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    final signIn = find.ancestor(
        of: find.text('Already have an account? Sign In', findRichText: true),
        matching: find.byType(TextButton));
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse);
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(Navigator.of(tester.element(find.byType(RegisterScreen))).canPop(),
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Successful login clears auth routes and opens startup destination',
      (tester) async {
    final provider = _LoginProvider();
    await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        initialRoute: '/login',
        routes: {
          '/': (_) => const Scaffold(body: Text('Sensei landing')),
          '/login': (_) => const LoginScreen(),
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'student@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(provider.calls, 1);
    provider.completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sensei landing'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(Navigator.of(tester.element(find.text('Sensei landing'))).canPop(),
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets(
        'Auth forms remain usable at $size with large text and keyboard',
        (tester) async {
      for (final screen in [
        const LoginScreen(),
        const RegisterScreen(),
        const PhoneVerificationScreen(),
        const SubjectSelectionScreen()
      ]) {
        await show(tester, screen, size, 2, keyboard: 220);
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
  testWidgets('Login retains validation and password visibility',
      (tester) async {
    await show(tester, const LoginScreen(), const Size(412, 915), 1);
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse);
  });
  testWidgets(
      'Phone verification keeps empty-number guidance and no legacy copy',
      (tester) async {
    await show(
        tester, const PhoneVerificationScreen(), const Size(320, 568), 1);
    await tester.ensureVisible(find.text('Send Code'));
    await tester.tap(find.text('Send Code'));
    await tester.pump();
    expect(find.text('Enter a phone number including the country code.'),
        findsOneWidget);
    expect(find.textContaining('Satori'), findsNothing);
    expect(find.textContaining('unlock AI'), findsNothing);
  });
  testWidgets('Subject chips retain multi-selection and custom subjects',
      (tester) async {
    await show(tester, const SubjectSelectionScreen(), const Size(412, 915), 1);
    await tester.tap(find.widgetWithText(FilterChip, 'Physics'));
    await tester.pump();
    expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Physics'))
            .selected,
        isTrue);
    await tester.enterText(find.byType(TextFormField), 'Design');
    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.widgetWithText(Chip, 'Design'), findsOneWidget);
  });
}
