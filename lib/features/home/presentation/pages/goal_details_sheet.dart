import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/home_assignment.dart';
import '../../data/models/long_term_goal.dart';
import '../../data/models/milestone.dart';
import '../../data/models/study_session.dart';
import '../controller/home_view_model.dart';

class GoalDetailsSheet extends StatefulWidget {
  const GoalDetailsSheet({
    super.key,
    required this.goal,
    required this.onToggleMilestone,
    required this.onDeleteGoal,
  });

  final LongTermGoal goal;
  final Future<void> Function(Milestone milestone, bool value) onToggleMilestone;
  final VoidCallback onDeleteGoal;

  @override
  State<GoalDetailsSheet> createState() => _GoalDetailsSheetState();
}

class _GoalDetailsSheetState extends State<GoalDetailsSheet> {
  final Map<String, bool> _localStatuses = {};

  void _cacheStatus(String milestoneId, bool value) {
    setState(() {
      _localStatuses[milestoneId] = value;
    });
  }

  bool _statusForDetail(MilestoneProgressInfo detail) {
    final cached = _localStatuses[detail.milestone.id];
    return cached ?? detail.milestone.isCompleted;
  }

  Future<void> _handleToggle(Milestone milestone, bool value) async {
    final previous = _localStatuses[milestone.id] ?? milestone.isCompleted;
    _cacheStatus(milestone.id, value);
    try {
      await widget.onToggleMilestone(milestone, value);
    } catch (error) {
      _cacheStatus(milestone.id, previous);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update milestone: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<HomeViewModel>();
    final milestoneDetails = viewModel.milestoneDetailsForGoal(widget.goal.id);
    _localStatuses.removeWhere(
      (key, _) => milestoneDetails.every((detail) => detail.milestone.id != key),
    );
    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.9,
      initialChildSize: 0.8,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                widget.goal.title,
                style: theme.textTheme.headlineSmall,
              ),
              if (widget.goal.description != null) ...[
                const SizedBox(height: 8),
                Text(widget.goal.description!),
              ],
              if (widget.goal.targetDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Target ${widget.goal.targetDate!.month}/${widget.goal.targetDate!.day}/${widget.goal.targetDate!.year}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Milestones',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (milestoneDetails.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No milestones added yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                Column(
                  children: milestoneDetails
                      .map(
                        (detail) => _MilestoneDetailCard(
                          detail: detail,
                          isChecked: _statusForDetail(detail),
                          onToggle: (value) =>
                              _handleToggle(detail.milestone, value),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: widget.onDeleteGoal,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete goal'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MilestoneDetailCard extends StatelessWidget {
  const _MilestoneDetailCard({
    required this.detail,
    required this.isChecked,
    required this.onToggle,
  });

  final MilestoneProgressInfo detail;
  final bool isChecked;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final milestone = detail.milestone;
    final dueLabel = milestone.dueDate != null
        ? 'Due ${milestone.dueDate!.month}/${milestone.dueDate!.day}/${milestone.dueDate!.year}'
        : 'No due date';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    if (value == null) return;
                    onToggle(value);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestone.title,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        dueLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: detail.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              detail.hasLinkedWork
                  ? '${detail.completedLinked}/${detail.totalLinked} linked tasks completed'
                  : 'Link assignments or study sessions to start tracking progress.',
              style: theme.textTheme.bodySmall,
            ),
            if (detail.linkedAssignments.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LinkedSectionHeader(label: 'Assignments'),
              for (final assignment in detail.linkedAssignments)
                _LinkedItemRow(
                  icon: Icons.assignment_outlined,
                  title: assignment.title,
                  subtitle: _assignmentSubtitle(context, assignment),
                  isDone: assignment.isCompleted,
                ),
            ],
            if (detail.linkedSessions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LinkedSectionHeader(label: 'Study sessions'),
              for (final session in detail.linkedSessions)
                _LinkedItemRow(
                  icon: Icons.timer_outlined,
                  title: _sessionTitle(session),
                  subtitle: _sessionSubtitle(context, session),
                  isDone: session.completionStatus == 'completed',
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _assignmentSubtitle(BuildContext context, HomeAssignment assignment) {
    final timeOfDay = TimeOfDay.fromDateTime(assignment.deadline);
    return '${timeOfDay.format(context)} · ${assignment.subject}';
  }

  static String _sessionTitle(StudySession session) {
    final started = session.startedAt;
    return 'Session on ${started.month}/${started.day}';
  }

  static String _sessionSubtitle(BuildContext context, StudySession session) {
    final started = session.startedAt;
    final timeOfDay = TimeOfDay.fromDateTime(started);
    final status = session.completionStatus;
    final formattedStatus = status.isEmpty
        ? 'Ongoing'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return '${timeOfDay.format(context)} · $formattedStatus';
  }
}

class _LinkedSectionHeader extends StatelessWidget {
  const _LinkedSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge,
    );
  }
}

class _LinkedItemRow extends StatelessWidget {
  const _LinkedItemRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
