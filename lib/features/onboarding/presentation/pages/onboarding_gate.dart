import 'package:flutter/material.dart';
import 'package:study_sensei/features/common/screens/startup_screen.dart';
import 'package:study_sensei/features/onboarding/data/onboarding_storage.dart';
import 'package:study_sensei/features/onboarding/presentation/pages/onboarding_screen.dart';

class OnboardingGate extends StatelessWidget {
  final WidgetBuilder completedBuilder;
  final OnboardingStorage storage;

  const OnboardingGate({
    super.key,
    required this.completedBuilder,
    this.storage = const OnboardingStorage(),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: storage.getOnboardingCompleted(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const StartupScreen();
        }

        if (snapshot.data == true) {
          return completedBuilder(context);
        }

        return OnboardingScreen(storage: storage);
      },
    );
  }
}
