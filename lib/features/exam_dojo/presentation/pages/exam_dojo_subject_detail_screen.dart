import 'package:flutter/material.dart';

import '../../data/models/exam_dojo_subject.dart';

class ExamDojoSubjectDetailScreen extends StatelessWidget {
  const ExamDojoSubjectDetailScreen({
    super.key,
    required this.subject,
    this.myProgress = 0,
    this.groupProgress,
    this.hasGroupProgress = false,
  });

  final ExamDojoSubject subject;
  final double myProgress;
  final double? groupProgress;
  final bool hasGroupProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: Text(
          subject.name,
          style: const TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryCard(subject: subject),
              const SizedBox(height: 20),
              Text('Progress', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              _ProgressCard(
                myProgress: myProgress,
                groupProgress: hasGroupProgress ? groupProgress : null,
              ),
              const SizedBox(height: 20),
              Text('Chapters', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              _ChapterList(chapters: subject.chapters),
              const SizedBox(height: 20),
              Text('Upcoming blocks', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              const _UpcomingBlocks(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Start next block'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.subject});

  final ExamDojoSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${subject.name} Exam',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDateTime(subject.examDate),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '18 days left',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${subject.chapters.length} chapters',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.myProgress, this.groupProgress});

  final double myProgress;
  final double? groupProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My progress', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: myProgress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            if (groupProgress != null) ...[
              Text('Group progress', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: groupProgress!,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ] else ...[
              Text('Group progress', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                'Appears once at least two members complete a session.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterList extends StatelessWidget {
  const _ChapterList({required this.chapters});

  final List<String> chapters;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Text(
        'No chapters added yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      children: chapters
          .map((chapter) => _ChapterRow(title: chapter, progress: 0))
          .toList(),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.title, required this.progress});

  final String title;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBlocks extends StatelessWidget {
  const _UpcomingBlocks();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No upcoming blocks yet. These will appear after your roadmap is generated.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

String _formatDateTime(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[(date.month - 1).clamp(0, 11)];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$month ${date.day}, ${date.year} - $hour:$minute $suffix';
}
