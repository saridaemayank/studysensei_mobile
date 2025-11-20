import 'package:flutter/material.dart';
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : requests.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No pending requests',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orangeAccent.shade200,
                Colors.pinkAccent.shade200,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              request.senderName.isNotEmpty
                  ? request.senderName[0].toUpperCase()
                  : '?',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.senderName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.senderEmail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'Sent ${_formatRelativeTime(request.sentAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Accept'),
            ),
            TextButton(
              onPressed: onDecline,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Decline'),
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
