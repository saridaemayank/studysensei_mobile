import 'package:flutter/material.dart';

import '../controller/home_view_model.dart';

class FocusTodayCard extends StatelessWidget {
  const FocusTodayCard({
    super.key,
    required this.task,
    required this.goalTitleResolver,
    required this.onStartSession,
    required this.onPlanNew,
    required this.hasActiveSession,
  });

  final HomeTask? task;
  final String? Function(String? goalId) goalTitleResolver;
  final void Function(HomeTask task) onStartSession;
  final VoidCallback onPlanNew;
  final bool Function(HomeTask task) hasActiveSession;

  @override
  Widget build(BuildContext context) {
    if (task == null) {
      return _EmptyFocusState(onCreateTapped: onPlanNew);
    }

    final theme = Theme.of(context);
    final isStudyBlock = task!.type == HomeTaskType.studyBlock;
    final chipLabel =
        isStudyBlock ? (task!.studyBlock?.subject?.isNotEmpty ?? false ? task!.studyBlock!.subject! : 'Study Block') : task!.assignment!.subject;
    final goalTitle = isStudyBlock
        ? goalTitleResolver(task!.studyBlock!.goalId)
        : goalTitleResolver(task!.assignment!.goalId);
    final primaryTitle = isStudyBlock ? task!.studyBlock!.title : task!.assignment!.title;
    final subtitle = isStudyBlock
        ? 'Starts ${_dueTimeLabel(context, task!.studyBlock!.scheduledAt)}'
        : 'Due ${_dueTimeLabel(context, task!.assignment!.deadline)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.85),
            theme.colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            label: Text(
              chipLabel,
              style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.black.withOpacity(0.25),
            side: BorderSide(color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 16),
          Text(
            primaryTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          if (goalTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              'Linked to: $goalTitle',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => onStartSession(task!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
              ),
              child: Text(
                hasActiveSession(task!)
                    ? 'Continue Session'
                    : 'Start Session',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dueTimeLabel(BuildContext context, DateTime deadline) {
    final local = deadline;
    final timeOfDay = TimeOfDay.fromDateTime(local);
    final formatted = timeOfDay.format(context);
    final now = DateTime.now();
    if (_isSameDay(local, now)) {
      return 'today at $formatted';
    }
    return '${local.month}/${local.day} at $formatted';
  }
}

class _EmptyFocusState extends StatelessWidget {
  const _EmptyFocusState({required this.onCreateTapped});
  final VoidCallback onCreateTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Focus Today',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'No assignments from your goals are due soon. Create a new session to stay ahead.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCreateTapped,
            child: const Text('Plan a new study block'),
          ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
