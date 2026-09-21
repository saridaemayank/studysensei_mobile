import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';

class PrivacySelector extends StatelessWidget {
  final GroupPrivacy initialValue;
  final ValueChanged<GroupPrivacy> onChanged;

  const PrivacySelector({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: GroupPrivacy.values.map((privacy) {
        final selected = privacy == initialValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(privacy),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? AppColors.borderActive
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PrivacyIcon(privacy: privacy, selected: selected),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPrivacyOption(privacy, context)),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.primaryLight
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrivacyOption(GroupPrivacy privacy, BuildContext context) {
    final description = switch (privacy) {
      GroupPrivacy.public =>
        'Anyone can find this Dojo and study with the group.',
      GroupPrivacy.private =>
        'Only members can see this Dojo. New members need an invite.',
      GroupPrivacy.inviteOnly =>
        'People can find it, but they need an invite to join.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(privacy.name, style: AppTypography.cardTitle),
        const SizedBox(height: 4),
        Text(
          description,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  final GroupPrivacy privacy;
  final bool selected;

  const _PrivacyIcon({required this.privacy, required this.selected});

  @override
  Widget build(BuildContext context) {
    final icon = switch (privacy) {
      GroupPrivacy.public => Icons.public,
      GroupPrivacy.private => Icons.lock_outline,
      GroupPrivacy.inviteOnly => Icons.mail_outline,
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: selected ? AppColors.primaryLight : AppColors.textSecondary,
      ),
    );
  }
}
