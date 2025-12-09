import 'package:flutter/material.dart';

import '../../data/models/home_assignment.dart';
import '../../data/models/study_block.dart';
import '../controller/home_view_model.dart';

class DailyTaskList extends StatelessWidget {
  const DailyTaskList({
    super.key,
    required this.tasks,
    required this.onToggleCompletion,
    required this.goalTitleResolver,
    required this.onStartSession,
    required this.onEditStudyBlock,
    required this.onDeleteStudyBlock,
    required this.hasActiveSession,
  });

  final List<HomeTask> tasks;
  final Future<void> Function(HomeAssignment assignment, bool value)
      onToggleCompletion;
  final String? Function(String? goalId) goalTitleResolver;
  final void Function(HomeTask task) onStartSession;
  final void Function(StudyBlock block) onEditStudyBlock;
  final Future<void> Function(StudyBlock block) onDeleteStudyBlock;
  final bool Function(HomeTask task) hasActiveSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No tasks planned for this day. Tap the + button to add one.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: tasks.map((task) {
        switch (task.type) {
          case HomeTaskType.assignment:
            final assignment = task.assignment!;
            final goalTitle = goalTitleResolver(assignment.goalId);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    assignment.subject.isNotEmpty
                        ? assignment.subject.characters.first.toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(assignment.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeLabel(context, assignment.deadline),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (goalTitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Chip(
                          label: Text('Goal: $goalTitle'),
                          backgroundColor:
                              theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
                trailing: Checkbox(
                  value: assignment.isCompleted,
                  onChanged: (value) {
                    if (value != null) {
                      onToggleCompletion(assignment, value);
                    }
                  },
                ),
                onLongPress: () => onStartSession(task),
              ),
            );
          case HomeTaskType.studyBlock:
            final block = task.studyBlock!;
            final goalTitle = goalTitleResolver(block.goalId);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _showBlockOptions(context, block),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: const Icon(Icons.schedule),
                ),
                title: Text(block.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_timeLabel(context, block.scheduledAt)} · ${block.durationMinutes} min',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (goalTitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Chip(
                          label: Text('Goal: $goalTitle'),
                          backgroundColor:
                              theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
                trailing: block.isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                        icon: Icon(
                          hasActiveSession(task)
                              ? Icons.restart_alt
                              : Icons.play_circle_fill,
                        ),
                        tooltip: hasActiveSession(task)
                            ? 'Continue Session'
                            : 'Start Session',
                        onPressed: () => onStartSession(task),
                      ),
              ),
            );
        }
      }).toList(),
    );
  }

  String _timeLabel(BuildContext context, DateTime deadline) {
    final timeOfDay = TimeOfDay.fromDateTime(deadline);
    return timeOfDay.format(context);
  }

  void _showBlockOptions(BuildContext context, StudyBlock block) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(
                hasActiveSession(HomeTask.studyBlock(block))
                    ? 'Continue Session'
                    : 'Start Session',
              ),
              onTap: () {
                Navigator.of(context).pop();
                onStartSession(HomeTask.studyBlock(block));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Study Block'),
              onTap: () {
                Navigator.of(context).pop();
                onEditStudyBlock(block);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Study Block'),
              onTap: () {
                Navigator.of(context).pop();
                onDeleteStudyBlock(block);
              },
            ),
          ],
        ),
      ),
    );
  }
}
