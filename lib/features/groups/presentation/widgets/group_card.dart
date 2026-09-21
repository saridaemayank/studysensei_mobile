import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onTap;
  final bool showMemberCount;
  final bool showAdminBadge;
  final bool isLoading;
  const GroupCard(
      {super.key,
      required this.group,
      this.onTap,
      this.showMemberCount = true,
      this.showAdminBadge = true,
      this.isLoading = false});

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        enabled: !isLoading,
        child: SenseiCard(
            onTap: isLoading ? null : onTap,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.groups_outlined,
                      color: AppColors.primaryLight)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(group.name, style: AppTypography.cardTitle),
                    if (showMemberCount) ...[
                      const SizedBox(height: 6),
                      Text(
                          '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                          style: AppTypography.bodyMedium),
                    ],
                    if (group.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(group.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium),
                    ],
                  ])),
              const SizedBox(width: 4),
              if (isLoading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
            ])),
      );
}
