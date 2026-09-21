import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';

class OnboardingActionButtons extends StatelessWidget {
  final bool isFinalPage;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  const OnboardingActionButtons({
    super.key,
    required this.isFinalPage,
    required this.onContinue,
    required this.onSkip,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (isFinalPage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SenseiPrimaryButton(
            text: 'Create Account',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: onCreateAccount,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onSignIn,
            child: const Text('Sign In'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SenseiPrimaryButton(
          text: 'Continue',
          icon: Icons.arrow_forward_rounded,
          onPressed: onContinue,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}
