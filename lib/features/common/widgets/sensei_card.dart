import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A calm, elevated card with 20px rounded corners and subtle borders.
class SenseiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final Gradient? gradient;

  const SenseiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.backgroundColor,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = border ??
        Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        );

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? AppColors.surfaceElevated)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: effectiveBorder,
      ),
      child: child,
    );

    if (onTap == null) {
      return cardContent;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: cardContent,
      ),
    );
  }
}
