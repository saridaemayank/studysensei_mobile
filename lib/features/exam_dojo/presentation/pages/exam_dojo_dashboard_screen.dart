import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/exam_dojo_group.dart';
import '../../data/models/exam_dojo_daily_block.dart';
import '../../data/models/exam_dojo_subject.dart';
import '../../services/exam_dojo_block_launcher.dart';
import '../../services/exam_dojo_logger.dart';
import '../controller/exam_dojo_controller.dart';
import 'exam_dojo_roadmap_screen.dart';
import 'exam_dojo_subject_detail_screen.dart';
import 'exam_dojo_subject_setup_screen.dart';

class ExamDojoDashboardScreen extends StatelessWidget {
  const ExamDojoDashboardScreen({
    super.key,
    required this.onOpenSetup,
    required this.dojo,
    required this.dailyBlocks,
    required this.isBlocksLoading,
    required this.blocksError,
    required this.onRetryBlocks,
    required this.subjectProgressById,
    required this.subjectProgressByName,
    required this.myProgress,
    required this.groupProgress,
    required this.isProgressLoading,
    required this.hasGroupProgress,
    required this.onRefreshProgress,
  });

  final VoidCallback onOpenSetup;
  final ExamDojoGroup dojo;
  final List<ExamDojoDailyBlock> dailyBlocks;
  final bool isBlocksLoading;
  final String? blocksError;
  final VoidCallback onRetryBlocks;
  final Map<String, double> subjectProgressById;
  final Map<String, double> subjectProgressByName;
  final double myProgress;
  final double groupProgress;
  final bool isProgressLoading;
  final bool hasGroupProgress;
  final Future<void> Function() onRefreshProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _ExamDojoDerivedData.fromDojo(
      dojo,
      dailyBlocks: dailyBlocks,
      subjectProgressById: subjectProgressById,
      subjectProgressByName: subjectProgressByName,
      myProgressRatio: myProgress,
      groupProgressRatio: groupProgress,
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Exam Dojo',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Prepare together, stay on track',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _GroupSummaryCard(data: sections.groupSummary),
            const SizedBox(height: 20),
            _UpcomingExamCard(data: sections.nextExam),
            const SizedBox(height: 28),
            _SectionHeader(title: "Today's Study Blocks"),
            const SizedBox(height: 8),
            Text(
              'Personalized from the shared roadmap and your progress.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (isBlocksLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (blocksError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to load blocks: $blocksError',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRetryBlocks,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (sections.todayBlocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Your personalized blocks will appear here once your roadmap is generated.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ...sections.todayBlocks.map(
                (block) => _StudyBlockCard(
                  block: block,
                  onStart: () => _startBlock(context, block.source),
                ),
              ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: _SectionHeader(title: 'Group Subject Progress'),
                ),
                TextButton.icon(
                  onPressed: isProgressLoading ? null : onRefreshProgress,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            if (isProgressLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!hasGroupProgress)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Group progress unlocks once at least two members complete a session.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            if (sections.subjectProgress.isEmpty)
              Text(
                'Add subjects to start tracking progress.',
                style: theme.textTheme.bodyMedium,
              )
            else
              _SubjectProgressList(subjects: sections.subjectProgress),
            const SizedBox(height: 28),
            _SectionHeader(title: 'Your Progress vs Group Average'),
            const SizedBox(height: 12),
            _ProgressComparisonCard(
              data: sections.comparison,
              hasGroupProgress: hasGroupProgress,
            ),
            const SizedBox(height: 28),
            _SectionHeader(title: 'Upcoming Exams'),
            const SizedBox(height: 12),
            if (sections.upcomingExams.isEmpty)
              Text(
                'No upcoming exams yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              _UpcomingExamScroller(
                exams: sections.upcomingExams,
                hasGroupProgress: hasGroupProgress,
              ),
            const SizedBox(height: 28),
            _SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 12),
            _QuickActions(
              onOpenSetup: onOpenSetup,
              onOpenRoadmap: () => _openRoadmap(context),
              onOpenSubjectSetup: () => _openSubjectSetup(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoadmap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExamDojoRoadmapScreen(dojo: dojo),
      ),
    );
  }

  void _openSubjectSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExamDojoSubjectSetupScreen(),
      ),
    );
  }

  void _startBlock(BuildContext context, ExamDojoDailyBlock block) async {
    final messenger = ScaffoldMessenger.of(context);
    ExamDojoLogger.log(
      'ui.dashboard.startBlock.tap',
      details: {
        'dojoId': dojo.id,
        'blockId': block.id,
        'date': block.date,
        'subject': block.subjectName,
      },
    );
    try {
      await ExamDojoBlockLauncher()
          .ensureStudyBlockFromDaily(block: block, dojoId: dojo.id);
      if (context.mounted) {
        context.read<ExamDojoController>().retryDailyBlocks();
      }
      ExamDojoLogger.log(
        'ui.dashboard.startBlock.success',
        details: {'dojoId': dojo.id, 'blockId': block.id},
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Study block added to your schedule.')),
      );
    } catch (error) {
      ExamDojoLogger.log(
        'ui.dashboard.startBlock.error',
        details: {
          'dojoId': dojo.id,
          'blockId': block.id,
          'message': error.toString(),
        },
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Unable to start block: $error'),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({required this.data});

  final _GroupSummary data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.sports_martial_arts,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.memberCount} members - ${data.subjectCount} subjects',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${data.daysToNextExam}d',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _AvatarStack(avatars: data.memberInitials),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group completion',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: data.groupCompletion,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Next exam: ${data.nextExamLabel}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars});

  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) {
      return const SizedBox.shrink();
    }
    final width = 32 + (avatars.length - 1) * 20.0;
    return SizedBox(
      width: width,
      height: 34,
      child: Stack(
        children: List.generate(avatars.length, (index) {
          return Positioned(
            left: index * 20.0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
              child: Text(
                avatars[index],
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _UpcomingExamCard extends StatelessWidget {
  const _UpcomingExamCard({required this.data});

  final _UpcomingExam data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.daysLeft} days left',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.examDateLabel,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _ProgressRow(label: 'Group progress', value: data.groupProgress),
            const SizedBox(height: 8),
            _ProgressRow(label: 'My progress', value: data.myProgress),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _StudyBlockCard extends StatelessWidget {
  const _StudyBlockCard({required this.block, required this.onStart});

  final _StudyBlock block;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Icon(
                Icons.schedule,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.subject,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    block.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${block.type} - ${block.durationMinutes} min',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onStart,
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectProgressList extends StatelessWidget {
  const _SubjectProgressList({required this.subjects});

  final List<_SubjectProgress> subjects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: subjects
          .map((subject) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(subject.name),
                        Text('${(subject.progress * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: subject.progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ProgressComparisonCard extends StatelessWidget {
  const _ProgressComparisonCard({
    required this.data,
    required this.hasGroupProgress,
  });

  final _ProgressComparison data;
  final bool hasGroupProgress;

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
            Text(
              'You are ${data.deltaLabel} the group average',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _ComparisonBar(label: 'You', value: data.myProgress),
            const SizedBox(height: 8),
            if (hasGroupProgress)
              _ComparisonBar(label: 'Group avg', value: data.groupAverage)
            else
              Text(
                'Group progress appears once at least two members complete a session.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _UpcomingExamScroller extends StatelessWidget {
  const _UpcomingExamScroller({
    required this.exams,
    required this.hasGroupProgress,
  });

  final List<_UpcomingExam> exams;
  final bool hasGroupProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final exam = exams[index];
          return InkWell(
            onTap: () => _openSubject(context, exam),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.subject,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exam.examDateLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${exam.daysLeft} days left',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSubject(BuildContext context, _UpcomingExam exam) {
    final subject = exam.subjectData;
    if (subject == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExamDojoSubjectDetailScreen(
          subject: subject,
          myProgress: exam.myProgress,
          groupProgress: hasGroupProgress ? exam.groupProgress : null,
          hasGroupProgress: hasGroupProgress,
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenSetup,
    required this.onOpenRoadmap,
    required this.onOpenSubjectSetup,
  });

  final VoidCallback onOpenSetup;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onOpenSubjectSetup;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionChip(
          label: 'Edit setup',
          icon: Icons.tune_rounded,
          onTap: onOpenSetup,
        ),
        _ActionChip(
          label: 'Add/Edit chapters',
          icon: Icons.menu_book_rounded,
          onTap: onOpenSubjectSetup,
        ),
        _ActionChip(
          label: 'View roadmap',
          icon: Icons.route_rounded,
          onTap: onOpenRoadmap,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamDojoDerivedData {
  _ExamDojoDerivedData({
    required this.groupSummary,
    required this.nextExam,
    required this.todayBlocks,
    required this.subjectProgress,
    required this.comparison,
    required this.upcomingExams,
  });

  final _GroupSummary groupSummary;
  final _UpcomingExam nextExam;
  final List<_StudyBlock> todayBlocks;
  final List<_SubjectProgress> subjectProgress;
  final _ProgressComparison comparison;
  final List<_UpcomingExam> upcomingExams;

  factory _ExamDojoDerivedData.fromDojo(
    ExamDojoGroup dojo, {
    required List<ExamDojoDailyBlock> dailyBlocks,
    Map<String, double> subjectProgressById = const <String, double>{},
    Map<String, double> subjectProgressByName = const <String, double>{},
    double myProgressRatio = 0,
    double groupProgressRatio = 0,
  }) {
    final subjects = List<ExamDojoSubject>.from(dojo.subjects)
      ..sort((a, b) => a.examDate.compareTo(b.examDate));

    final now = DateTime.now();
    final nextSubject =
        subjects.firstWhere((s) => s.examDate.isAfter(now), orElse: () {
      return subjects.isNotEmpty
          ? subjects.first
          : ExamDojoSubject(
              id: 'na',
              name: 'Upcoming Exam',
              examDate: now.add(const Duration(days: 14)),
              chapters: const [],
            );
    });

    final nextExam = _UpcomingExam(
      subject: nextSubject.name,
      examDateLabel: _formatDateTime(nextSubject.examDate),
      daysLeft: _daysLeft(nextSubject.examDate),
      groupProgress: groupProgressRatio,
      myProgress: subjectProgressById[nextSubject.id] ??
          subjectProgressByName[nextSubject.name] ??
          0.0,
      subjectData: nextSubject,
    );

    final summary = _GroupSummary(
      name: dojo.name,
      memberCount: dojo.memberIds.length,
      subjectCount: subjects.length,
      daysToNextExam: _daysLeft(nextSubject.examDate),
      groupCompletion: groupProgressRatio,
      nextExamLabel:
          '${nextSubject.name} - ${_formatDate(nextSubject.examDate)}',
      memberInitials: dojo.memberIds
          .take(4)
          .map((id) => id.isNotEmpty ? id[0].toUpperCase() : '?')
          .toList(),
    );

    final subjectProgress = subjects
        .map(
          (subject) => _SubjectProgress(
            name: subject.name,
            progress: subjectProgressById[subject.id] ??
                subjectProgressByName[subject.name] ??
                0.0,
          ),
        )
        .toList();
    subjectProgressByName.forEach((name, ratio) {
      final exists = subjectProgress.any((progress) => progress.name == name);
      if (!exists) {
        subjectProgress.add(_SubjectProgress(name: name, progress: ratio));
      }
    });

    final upcomingExams = subjects
        .where((subject) => subject.examDate.isAfter(now))
        .take(5)
        .map(
          (subject) => _UpcomingExam(
            subject: subject.name,
            examDateLabel: _formatDate(subject.examDate),
            daysLeft: _daysLeft(subject.examDate),
            groupProgress: groupProgressRatio,
            myProgress: subjectProgressById[subject.id] ??
                subjectProgressByName[subject.name] ??
                0.0,
            subjectData: subject,
          ),
        )
        .toList();

    return _ExamDojoDerivedData(
      groupSummary: summary,
      nextExam: nextExam,
      todayBlocks: dailyBlocks
          .map(
            (block) => _StudyBlock(
              subject: block.subjectName ?? 'Study Block',
              title: block.chapter ?? block.notes ?? 'Focus session',
              type: block.blockType,
              durationMinutes: block.durationMinutes,
              source: block,
            ),
          )
          .toList(),
      subjectProgress: subjectProgress,
      comparison: _ProgressComparison(
        myProgress: myProgressRatio,
        groupAverage: groupProgressRatio,
      ),
      upcomingExams: upcomingExams,
    );
  }

  static int _daysLeft(DateTime target) {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    return target.difference(dateOnly).inDays.clamp(0, 3650);
  }

  static String _formatDate(DateTime date) {
    return '${_monthLabel(date.month)} ${date.day}';
  }

  static String _formatDateTime(DateTime date) {
    return '${_monthLabel(date.month)} ${date.day}, ${date.year} - ${_timeLabel(date)}';
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static String _monthLabel(int month) {
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
    return months[(month - 1).clamp(0, 11)];
  }
}

class _GroupSummary {
  const _GroupSummary({
    required this.name,
    required this.memberCount,
    required this.subjectCount,
    required this.daysToNextExam,
    required this.groupCompletion,
    required this.nextExamLabel,
    required this.memberInitials,
  });

  final String name;
  final int memberCount;
  final int subjectCount;
  final int daysToNextExam;
  final double groupCompletion;
  final String nextExamLabel;
  final List<String> memberInitials;
}

class _UpcomingExam {
  const _UpcomingExam({
    required this.subject,
    required this.examDateLabel,
    required this.daysLeft,
    required this.groupProgress,
    required this.myProgress,
    this.subjectData,
  });

  final String subject;
  final String examDateLabel;
  final int daysLeft;
  final double groupProgress;
  final double myProgress;
  final ExamDojoSubject? subjectData;
}

class _StudyBlock {
  const _StudyBlock({
    required this.subject,
    required this.title,
    required this.type,
    required this.durationMinutes,
    required this.source,
  });

  final String subject;
  final String title;
  final String type;
  final int durationMinutes;
  final ExamDojoDailyBlock source;
}

class _SubjectProgress {
  const _SubjectProgress({required this.name, required this.progress});

  final String name;
  final double progress;
}

class _ProgressComparison {
  const _ProgressComparison(
      {required this.myProgress, required this.groupAverage});

  final double myProgress;
  final double groupAverage;

  String get deltaLabel {
    final delta = (myProgress - groupAverage) * 100;
    if (delta.abs() < 1) return 'about the same as';
    if (delta > 0) return '${delta.round()}% ahead of';
    return '${delta.abs().round()}% behind';
  }
}
