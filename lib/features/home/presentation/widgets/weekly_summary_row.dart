import 'package:flutter/material.dart';

import '../controller/home_view_model.dart';

class WeeklySummaryRow extends StatelessWidget {
  const WeeklySummaryRow({
    super.key,
    required this.summary,
  });

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        icon: Icons.access_time,
        title: 'Study Time',
        value: _formatDuration(summary.totalStudyTime),
        color: Theme.of(context).colorScheme.primary,
      ),
      _SummaryCard(
        icon: Icons.flag_rounded,
        title: 'Milestones',
        value: '${summary.completedMilestones}/${summary.totalMilestones}',
        color: Theme.of(context).colorScheme.secondary,
      ),
      _SummaryCard(
        icon: Icons.local_fire_department,
        title: 'Streak',
        value: '${summary.streakDays} days',
        color: Theme.of(context).colorScheme.error,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: cards
          .map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: card,
                ),
              ))
          .toList(),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inMinutes / 60;
    return '${hours.toStringAsFixed(1)}h';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
