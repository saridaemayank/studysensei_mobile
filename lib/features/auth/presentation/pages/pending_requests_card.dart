import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';

class PendingRequestsCard extends StatelessWidget {
  final bool loading;
  final List<FriendRequestModel> requests;
  final void Function(FriendRequestModel request) onAccept;
  final void Function(FriendRequestModel request) onDecline;

  const PendingRequestsCard({
    super.key,
    required this.loading,
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SenseiCard(
      padding: const EdgeInsets.all(16),
      child: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : requests.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.people_outline,
                        size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'No pending requests',
                      style: AppTypography.bodyLarge,
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final request in requests) ...[
                      _PendingRequestRow(
                        request: request,
                        onAccept: () => onAccept(request),
                        onDecline: () => onDecline(request),
                      ),
                      if (request != requests.last)
                        Divider(
                          height: 24,
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _PendingRequestRow extends StatelessWidget {
  final FriendRequestModel request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingRequestRow({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.surfaceHighlight,
              foregroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.senderName, style: AppTypography.cardTitle),
                  const SizedBox(height: 4),
                  Text(request.senderEmail, style: AppTypography.bodyMedium),
                  Text('Sent ${_formatRelativeTime(request.sentAt)}',
                      style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Semantics(
              label: 'Accept request from ${request.senderName}',
              child: ElevatedButton(
                  onPressed: onAccept, child: const Text('Accept')),
            ),
            Semantics(
              label: 'Decline request from ${request.senderName}',
              child: TextButton(
                  onPressed: onDecline, child: const Text('Decline')),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime sentAt) {
    final now = DateTime.now();
    final difference = now.difference(sentAt);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
  }
}
