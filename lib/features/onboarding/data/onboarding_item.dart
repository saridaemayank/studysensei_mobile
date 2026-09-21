import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';

enum OnboardingVisualType {
  companion,
  explanation,
  dojo,
  focus,
  ready,
}

class OnboardingItem {
  final String headline;
  final String description;
  final OnboardingVisualType visualType;
  final IconData icon;
  final Color accentColor;
  final bool isFinalPage;

  const OnboardingItem({
    required this.headline,
    required this.description,
    required this.visualType,
    required this.icon,
    required this.accentColor,
    this.isFinalPage = false,
  });
}

const onboardingItems = [
  OnboardingItem(
    headline: 'Welcome to StudySensei',
    description: 'The smarter way to stay consistent with your studies.',
    visualType: OnboardingVisualType.companion,
    icon: Icons.school_rounded,
    accentColor: AppColors.primary,
  ),
  OnboardingItem(
    headline: 'Understand faster',
    description:
        'Ask doubts, explore concepts, and learn with explanations that feel simple.',
    visualType: OnboardingVisualType.explanation,
    icon: Icons.auto_awesome_rounded,
    accentColor: AppColors.info,
  ),
  OnboardingItem(
    headline: 'Study with your Dojo',
    description:
        'Create study groups, share assignments, chat, and stay connected with friends.',
    visualType: OnboardingVisualType.dojo,
    icon: Icons.groups_rounded,
    accentColor: AppColors.primaryLight,
  ),
  OnboardingItem(
    headline: 'Build better focus',
    description:
        'Plan your study time, stay on track, and turn small daily sessions into progress.',
    visualType: OnboardingVisualType.focus,
    icon: Icons.timer_rounded,
    accentColor: AppColors.warning,
  ),
  OnboardingItem(
    headline: 'Ready to begin?',
    description:
        'Create your account or sign in to continue your learning journey.',
    visualType: OnboardingVisualType.ready,
    icon: Icons.check_circle_rounded,
    accentColor: AppColors.success,
    isFinalPage: true,
  ),
];
