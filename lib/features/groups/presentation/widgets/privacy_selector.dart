import 'package:flutter/material.dart';
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
        return RadioListTile<GroupPrivacy>(
          title: _buildPrivacyOption(privacy, context),
          value: privacy,
          groupValue: initialValue,
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildPrivacyOption(GroupPrivacy privacy, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData icon;
    String description;
    Color color;

    switch (privacy) {
      case GroupPrivacy.public:
        icon = Icons.public;
        description = 'Anyone can see the group and its members. Anyone can join.';
        color = colorScheme.primary;
        break;
      case GroupPrivacy.private:
        icon = Icons.lock_outline;
        description = 'Only members can see the group and its members. New members must be invited.';
        color = colorScheme.primary;
        break;
      case GroupPrivacy.inviteOnly:
        icon = Icons.mail_outline;
        description = 'Anyone can see the group, but only members can see who is in the group. New members must be invited.';
        color = colorScheme.primary;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                privacy.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
