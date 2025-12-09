import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/auth/presentation/pages/phone_verification_screen.dart';
import 'package:study_sensei/features/auth/register/screens/register_screen.dart';
import 'package:study_sensei/features/auth/register/screens/subject_selection_screen.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';
import 'package:study_sensei/features/friends/presentation/bloc/friend_bloc.dart';
import 'package:study_sensei/features/groups/presentation/bloc/group_bloc.dart';
import 'package:study_sensei/features/home/services/study_session_notification_service.dart';
import 'package:study_sensei/core/navigation/navigation_service.dart';
import 'package:study_sensei/core/services/app_lock_provider.dart';
import 'package:study_sensei/core/services/push_notification_service.dart';
import 'package:study_sensei/firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app' && e.code != 'app/duplicate-app') {
      rethrow;
    }
  }

  await PushNotificationService.instance.initialize();
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
              theme: ThemeData(
                primarySwatch: Colors.orange,
                useMaterial3: true,
                fontFamily: 'SubHeading',
                textTheme: const TextTheme(
                  displayLarge: TextStyle(
                    fontFamily: 'Headings',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  titleLarge: TextStyle(
                    fontFamily: 'SubHeading',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                  bodyLarge: TextStyle(
                    fontFamily: 'SubHeading',
                    fontSize: 16,
                    color: Color(0xFF4A5568),
                  ),
                  labelLarge: TextStyle(
                    fontFamily: 'SubHeading',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  iconTheme: IconThemeData(color: Colors.black),
                  titleTextStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              initialRoute: '/',
              routes: {
                '/': (context) => Consumer<UserProvider>(
                  builder: (context, userProvider, _) {
                    if (userProvider.user == null) {
                      return const LoginScreen();
                    } else {
                      return const MainLayout();
                    }
                  },
                ),
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/assignments': (context) => const MainLayout(initialIndex: 1),
                '/friends': (context) => const MainLayout(initialIndex: 2),
                '/profile': (context) => const MainLayout(initialIndex: 4),
                '/subject-selection': (context) =>
                    const SubjectSelectionScreen(),
                PhoneVerificationScreen.routeName: (context) =>
                    const PhoneVerificationScreen(),
              },
              onGenerateRoute: (settings) {
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
                        return const LoginScreen();
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
