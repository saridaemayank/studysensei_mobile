import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int itemCount;

  const OnboardingProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onboarding page ${currentIndex + 1} of $itemCount',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(itemCount, (index) {
          final selected = index == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: selected ? 26 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : AppColors.borderMedium,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
