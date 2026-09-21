import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:study_sensei/features/common/screens/startup_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/auth/presentation/pages/phone_verification_screen.dart';
import 'package:study_sensei/features/auth/register/screens/register_screen.dart';
import 'package:study_sensei/features/auth/register/screens/subject_selection_screen.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';
import 'package:study_sensei/features/onboarding/presentation/pages/onboarding_gate.dart';
import 'package:study_sensei/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:study_sensei/features/routes/app_routes.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_bloc.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group_bloc.dart';
import 'package:study_sensei/features/home/services/study_session_notification_service.dart';
import 'package:study_sensei/core/navigation/navigation_service.dart';
import 'package:study_sensei/core/services/app_lock_provider.dart';
import 'package:study_sensei/core/services/push_notification_service.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const StartupScreen()));

  final bool supportsFirebaseMessaging = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  if (supportsFirebaseMessaging) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app' && e.code != 'app/duplicate-app') {
      rethrow;
    }
  }

  if (supportsFirebaseMessaging) {
    await PushNotificationService.instance.initialize();
  }
  await StudySessionNotificationService.instance.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider()..initAuth(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => AppLockProvider()..initialize(),
          lazy: false,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => FriendBloc()),
          BlocProvider(create: (context) => GroupBloc()),
        ],
        child: Builder(
          builder: (context) {
            return MaterialApp(
              title: 'StudySensei',
              debugShowCheckedModeBanner: false,
              navigatorKey: NavigationService.navigatorKey,
              theme: AppTheme.darkTheme,
              initialRoute: '/',
              routes: {
                '/': (context) => OnboardingGate(
                      completedBuilder: (context) => Consumer<UserProvider>(
                        builder: (context, userProvider, _) {
                          if (userProvider.user == null) {
                            return const OnboardingScreen(
                                showAuthChoices: true);
                          }
                          return const MainLayout();
                        },
                      ),
                    ),
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/onboarding': (context) => const OnboardingScreen(),
                '/sensei': (context) => const MainLayout(initialIndex: 0),
                '/assignments': (context) => const MainLayout(initialIndex: 2),
                '/friends': (context) => const MainLayout(initialIndex: 2),
                '/focus': (context) => const MainLayout(initialIndex: 1),
                '/profile': (context) => const MainLayout(initialIndex: 3),
                '/subject-selection': (context) =>
                    const SubjectSelectionScreen(),
                PhoneVerificationScreen.routeName: (context) =>
                    const PhoneVerificationScreen(),
              },
              onGenerateRoute: (settings) {
                if (settings.name == AppRoutes.senseiReview) {
                  return AppRoutes.generateRoute(settings);
                }
                // Handle any other routes if needed
                if (settings.name == '/main') {
                  return MaterialPageRoute(
                    builder: (context) => const MainLayout(),
                  );
                }
                return null;
              },
              onUnknownRoute: (settings) {
                // Handle unknown routes by redirecting to home
                return MaterialPageRoute(
                  builder: (context) => Consumer<UserProvider>(
                    builder: (context, userProvider, _) {
                      if (userProvider.user == null) {
                        return const OnboardingScreen(showAuthChoices: true);
                      } else {
                        return const MainLayout();
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
