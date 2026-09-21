import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';

/// Shown only while the existing startup work runs; no timer or extra route.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Semantics(
                header: true,
                child: const Text('StudySensei',
                    textAlign: TextAlign.center,
                    style: AppTypography.pageTitle)),
            const SizedBox(height: 12),
            const Text('Show. Understand. Learn.',
                textAlign: TextAlign.center, style: AppTypography.bodyLarge),
          ]),
        ))),
      );
}
