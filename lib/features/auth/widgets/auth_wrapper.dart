import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';
import 'package:study_sensei/features/routes/app_routes.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    // Check if user is logged in
    if (user != null) {
      // User is logged in, go to main screen
      return const MainLayout();
    } else {
      // User is not logged in, go to login screen
      return const LoginScreen();
    }
  }
}
