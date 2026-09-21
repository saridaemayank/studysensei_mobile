import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Navigation item model for Sensei bottom navigation.
class SenseiNavItem {
  final IconData icon;
  final String label;

  const SenseiNavItem({
    required this.icon,
    required this.label,
  });
}

/// Quiet, elevated bottom navigation bar for the 4 primary tabs:
/// SENSEI (0), FOCUS (1), DOJOS (2), PROFILE (3).
class SenseiBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SenseiBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<SenseiNavItem> items = [
    SenseiNavItem(icon: Icons.auto_awesome_rounded, label: 'Sensei'),
    SenseiNavItem(icon: Icons.center_focus_strong_rounded, label: 'Focus'),
    SenseiNavItem(icon: Icons.groups_rounded, label: 'Dojos'),
    SenseiNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.circular(16),
                    splashColor: AppColors.primary.withValues(alpha: 0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
