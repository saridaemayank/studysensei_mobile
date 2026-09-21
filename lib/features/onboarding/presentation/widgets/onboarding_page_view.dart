import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/onboarding/data/onboarding_item.dart';

class OnboardingPageView extends StatelessWidget {
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final int currentIndex;

  const OnboardingPageView({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: onboardingItems.length,
      itemBuilder: (context, index) {
        final item = onboardingItems[index];
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _OnboardingPage(
            key: ValueKey(item.headline),
            item: item,
          ),
        );
      },
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;

  const _OnboardingPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final visualSize = width.clamp(220.0, 310.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              image: true,
              label: item.headline,
              child: SizedBox(
                width: visualSize,
                height: visualSize,
                child: _OnboardingVisual(item: item),
              ),
            ),
            const SizedBox(height: 34),
            Semantics(
              header: true,
              child: Text(
                item.headline,
                textAlign: TextAlign.center,
                style: AppTypography.pageTitle,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  final OnboardingItem item;

  const _OnboardingVisual({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.accentColor.withValues(alpha: 0.08),
            boxShadow: [
              BoxShadow(
                color: item.accentColor.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 34,
          bottom: 20,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: item.accentColor.withValues(alpha: 0.3)),
            ),
          ),
        ),
        Positioned(
          top: 18,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accentColor.withValues(alpha: 0.18),
              border:
                  Border.all(color: item.accentColor.withValues(alpha: 0.4)),
            ),
            child: Icon(item.icon, size: 48, color: item.accentColor),
          ),
        ),
        ..._decorationsFor(item),
      ],
    );
  }

  List<Widget> _decorationsFor(OnboardingItem item) {
    switch (item.visualType) {
      case OnboardingVisualType.companion:
        return [
          _MiniCard(
            left: 26,
            bottom: 54,
            color: AppColors.primary,
            icon: Icons.lightbulb_rounded,
            label: 'Doubt',
          ),
          _MiniCard(
            right: 18,
            bottom: 82,
            color: AppColors.info,
            icon: Icons.auto_awesome_rounded,
            label: 'Explain',
          ),
        ];
      case OnboardingVisualType.explanation:
        return [
          _MiniCard(
            left: 20,
            bottom: 58,
            color: AppColors.info,
            icon: Icons.menu_book_rounded,
            label: 'Concept',
          ),
          const _LineStack(right: 32, bottom: 70),
        ];
      case OnboardingVisualType.dojo:
        return [
          _AvatarDot(left: 36, bottom: 86, color: AppColors.primary),
          _AvatarDot(right: 44, bottom: 94, color: AppColors.info),
          _MiniCard(
            left: 48,
            right: 48,
            bottom: 34,
            color: AppColors.primaryLight,
            icon: Icons.chat_bubble_rounded,
            label: 'PYQs',
          ),
        ];
      case OnboardingVisualType.focus:
        return [
          Positioned(
            left: 54,
            right: 54,
            bottom: 54,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderMedium),
              ),
              child: const Center(
                child: Text(
                  '25:00',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ];
      case OnboardingVisualType.ready:
        return [
          _MiniCard(
            left: 42,
            right: 42,
            bottom: 44,
            color: AppColors.success,
            icon: Icons.check_rounded,
            label: 'Ready',
          ),
        ];
    }
  }
}

class _MiniCard extends StatelessWidget {
  final double? left;
  final double? right;
  final double? bottom;
  final Color color;
  final IconData icon;
  final String label;

  const _MiniCard({
    this.left,
    this.right,
    this.bottom,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  final double? left;
  final double? right;
  final double? bottom;
  final Color color;

  const _AvatarDot({this.left, this.right, this.bottom, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Icon(Icons.person_rounded, color: color),
      ),
    );
  }
}

class _LineStack extends StatelessWidget {
  final double? right;
  final double? bottom;

  const _LineStack({this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (index) => Container(
            width: 72 - index * 12,
            height: 8,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
