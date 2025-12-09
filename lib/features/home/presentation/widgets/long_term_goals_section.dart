import 'package:flutter/material.dart';

import '../../data/models/long_term_goal.dart';
import 'goal_card.dart';

class LongTermGoalsSection extends StatelessWidget {
  const LongTermGoalsSection({
    super.key,
    required this.goals,
    required this.onAddGoal,
    this.onViewAll,
    required this.onGoalSelected,
    required this.progressForGoal,
    required this.statusForGoal,
  });

  final List<LongTermGoal> goals;
  final VoidCallback onAddGoal;
  final VoidCallback? onViewAll;
  final ValueChanged<LongTermGoal> onGoalSelected;
  final double Function(String goalId) progressForGoal;
  final String Function(String goalId) statusForGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Long-Term Goals',
              style: theme.textTheme.titleLarge,
            ),
            if (onViewAll != null && goals.isNotEmpty)
              TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              if (index == goals.length) {
                return _AddGoalCard(onTap: onAddGoal);
              }
              final goal = goals[index];
              return GoalCard(
                goal: goal,
                progress: progressForGoal(goal.id),
                statusText: statusForGoal(goal.id),
                onTap: () => onGoalSelected(goal),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: goals.length + 1,
          ),
        ),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Set your first long-term goal to organize study blocks.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _AddGoalCard extends StatelessWidget {
  const _AddGoalCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'New Goal',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
