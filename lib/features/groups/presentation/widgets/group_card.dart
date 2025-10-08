import 'package:flutter/material.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onTap;
  final bool showMemberCount;
  final bool showAdminBadge;
  final bool isLoading;

  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.showMemberCount = true,
    this.showAdminBadge = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Stack(
        children: [
          InkWell(
            onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Group avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Icon(
                      Icons.sports_martial_arts,
                      size: 30,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  // Group info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (group.isAdmin && showAdminBadge) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  'Admin',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          group.description.isNotEmpty
                              ? group.description
                              : 'No description',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              // Dojo metadata
              Row(
                children: [
                  _buildMetadataItem(
                    context,
                    icon: Icons.people,
                    text: '${group.memberIds.length} member${group.memberIds.length != 1 ? 's' : ''} in dojo',
                  ),
                  const SizedBox(width: 16.0),
                  _buildMetadataItem(
                    context,
                    icon: _getPrivacyIcon(group.privacy),
                    text: group.privacy.name,
                  ),
                ],
              ),
            ],
              ),
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 4.0),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  IconData _getPrivacyIcon(GroupPrivacy privacy) {
    switch (privacy) {
      case GroupPrivacy.public:
        return Icons.public;
      case GroupPrivacy.private:
        return Icons.lock_outline;
      case GroupPrivacy.inviteOnly:
        return Icons.mail_outline;
    }
  }
}
