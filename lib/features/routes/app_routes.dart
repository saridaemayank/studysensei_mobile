import 'package:flutter/material.dart';
import '../onboarding/presentation/pages/onboarding_screen.dart';
import '../sensei/screens/sensei_review_screen.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/auth/register/screens/register_screen.dart';
import 'package:study_sensei/features/auth/register/screens/subject_selection_screen.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Route names
  static const String login = '/login';
  static const String register = '/register';
  // Route names
  static const String home = '/';
  static const String main = '/main';
  static const String assignments = '/assignments';
  static const String subjectSelection = '/subject-selection';
  static const String sensei = '/sensei';
  static const String profile = '/profile';
  static const String focus = '/focus';
  static const String onboarding = '/onboarding';
  static const String senseiReview = '/sensei/review';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case profile:
      case focus:
      case senseiReview:
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => _getPage(settings.name!, settings.arguments));
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case main:
        return MaterialPageRoute(builder: (_) => const MainLayout());
      case assignments:
        return MaterialPageRoute(
          builder: (_) => const MainLayout(initialIndex: 2),
        );
      case subjectSelection:
        return MaterialPageRoute(
          builder: (_) => const SubjectSelectionScreen(),
        );
      case sensei:
        return MaterialPageRoute(
          builder: (_) => const MainLayout(initialIndex: 0),
        );
      case home:
      default:
        // Default to login for now, can be changed to home/dashboard later
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }

  // Navigation methods
  static Future<T?> push<T extends Object?>({
    required BuildContext context,
    required String routeName,
    Object? arguments,
    bool replace = false,
  }) {
    if (replace) {
      return Navigator.of(
        context,
      ).pushReplacementNamed(routeName, arguments: arguments);
    }
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>({
    required BuildContext context,
    required String routeName,
    Object? arguments,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MaterialPageRoute(
        settings: RouteSettings(name: routeName, arguments: arguments),
        builder: (_) => _getPage(routeName, arguments),
      ),
      result: result,
    );
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }

  static Future<T?> pushAndRemoveUntil<T extends Object?>({
    required BuildContext context,
    required String newRouteName,
    required bool Function(Route<dynamic>) predicate,
    Object? arguments,
  }) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      MaterialPageRoute(
        settings: RouteSettings(name: newRouteName, arguments: arguments),
        builder: (_) => _getPage(newRouteName, arguments),
      ),
      predicate,
    );
  }

  // Helper method to get the page widget based on route name
  static Widget _getPage(String routeName, Object? arguments) {
    switch (routeName) {
      case onboarding:
        return const OnboardingScreen();
      case profile:
        return const MainLayout(initialIndex: 3);
      case focus:
        return const MainLayout(initialIndex: 1);
      case senseiReview:
        if (arguments is Map && arguments['videoUrl'] is String) {
          return SenseiReviewScreen(
            subject: arguments['subject'] as String? ?? 'General',
            concept: arguments['concept'] as String? ?? '',
            isFaceBlurred: arguments['isFaceBlurred'] == true,
            isMuted: arguments['isMuted'] == true,
            duration: arguments['duration'] as int? ?? 0,
            videoUrl: arguments['videoUrl'] as String,
          );
        }
        return const Scaffold(
            body: SafeArea(
                child: Center(child: Text("Couldn't open this lesson."))));
      case login:
        return const LoginScreen();
      case register:
        return const RegisterScreen();
      case main:
        return const MainLayout();
      case assignments:
        return const MainLayout(initialIndex: 2);
      case subjectSelection:
        return const SubjectSelectionScreen();
      case sensei:
        return const MainLayout(initialIndex: 0);
      case home:
      default:
        return const LoginScreen(); // Default to login
    }
  }
}
