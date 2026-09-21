import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/exam_dojo_daily_block.dart';
import '../../data/models/exam_dojo_group.dart';
import '../../services/exam_dojo_block_launcher.dart';
import '../../services/exam_dojo_logger.dart';
import '../controller/exam_dojo_controller.dart';

class ExamDojoRoadmapScreen extends StatefulWidget {
  const ExamDojoRoadmapScreen({super.key, required this.dojo});

  final ExamDojoGroup dojo;

  @override
  State<ExamDojoRoadmapScreen> createState() => _ExamDojoRoadmapScreenState();
}

class _ExamDojoRoadmapScreenState extends State<ExamDojoRoadmapScreen> {
  late Future<_RoadmapPayload> _roadmapFuture;

  @override
  void initState() {
    super.initState();
    _roadmapFuture = _loadRoadmap();
  }

  Future<_RoadmapPayload> _loadRoadmap() async {
    ExamDojoLogger.log(
      'ui.roadmap.load.start',
      details: {
        'dojoId': widget.dojo.id,
        'version': widget.dojo.roadmapVersion
      },
    );
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('exam_dojos').doc(widget.dojo.id);

      DocumentSnapshot<Map<String, dynamic>>? snapshot;
      if (widget.dojo.roadmapVersion != null &&
          widget.dojo.roadmapVersion!.isNotEmpty) {
        snapshot = await docRef
            .collection('roadmap_snapshots')
            .doc(widget.dojo.roadmapVersion)
            .get();
      } else {
        final query = await docRef
            .collection('roadmap_snapshots')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          snapshot = query.docs.first;
        }
      }

      if (snapshot == null || !snapshot.exists) {
        ExamDojoLogger.log(
          'ui.roadmap.load.empty',
          details: {'dojoId': widget.dojo.id},
        );
        return const _RoadmapPayload.empty();
      }

      final data = snapshot.data() ?? {};
      final payload = _extractRoadmapPayload(data);

      final blocks =
          _mapList(payload['blocks']).map(ExamDojoDailyBlock.fromMap).toList();
      final metadata = _mapFrom(payload['metadata']);
      final weeks =
          _mapList(payload['weeks']).map(_RoadmapWeek.fromMap).toList();
      final milestones = _mapList(payload['milestones'])
          .map(_RoadmapMilestone.fromMap)
          .toList();
      final revisionSource =
          payload['revision_slots'] ?? payload['revisionSlots'];
      final revisionSlots =
          _mapList(revisionSource).map(_RevisionSlot.fromMap).toList();

      ExamDojoLogger.log(
        'ui.roadmap.load.success',
        details: {
          'dojoId': widget.dojo.id,
          'version': payload['version'] ?? data['version'],
          'blockCount': blocks.length,
        },
      );
      return _RoadmapPayload(
        version: (payload['version'] ?? data['version'])?.toString(),
        blocks: blocks,
        metadata: metadata,
        weeks: weeks,
        milestones: milestones,
        revisionSlots: revisionSlots,
      );
    } catch (error) {
      ExamDojoLogger.log(
        'ui.roadmap.load.error',
        details: {'dojoId': widget.dojo.id, 'message': error.toString()},
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Shared Roadmap',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<_RoadmapPayload>(
          future: _roadmapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Unable to load roadmap: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }
            final payload = snapshot.data ?? const _RoadmapPayload.empty();
            final groupedDays = _groupBlocksByDay(payload.blocks);

            if (groupedDays.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No roadmap sessions available yet. Generate a plan to see upcoming study blocks.',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (payload.metadata.isNotEmpty)
                  _MetadataCard(metadata: payload.metadata),
                if (payload.version != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Version: ${payload.version}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (payload.weeks.isNotEmpty) ...[
                  _SectionLabel(text: 'Weekly focus'),
                  ...payload.weeks
                      .map((week) => _WeekCard(week: week))
                      .toList(),
                  const SizedBox(height: 20),
                ],
                if (payload.milestones.isNotEmpty) ...[
                  _SectionLabel(text: 'Milestones'),
                  ...payload.milestones
                      .map((milestone) => _MilestoneCard(milestone: milestone))
                      .toList(),
                  const SizedBox(height: 20),
                ],
                if (payload.revisionSlots.isNotEmpty) ...[
                  _SectionLabel(text: 'Revision slots'),
                  ...payload.revisionSlots
                      .map((slot) => _RevisionSlotChip(slot: slot))
                      .toList(),
                  const SizedBox(height: 20),
                ],
                _SectionLabel(text: 'Upcoming sessions'),
                const SizedBox(height: 12),
                ...groupedDays.map(
                  (day) => _RoadmapDaySection(
                    day: day,
                    onStart: (block) => _startBlock(context, block),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  DateTime _blockDate(ExamDojoDailyBlock block) {
    if (block.sessionDate != null) return block.sessionDate!;
    if (block.date.isNotEmpty) {
      final parsed = DateTime.tryParse(block.date);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day, 8);
      }
      final segments = block.date.split('-').map(int.tryParse).toList();
      if (segments.length == 3 &&
          segments[0] != null &&
          segments[1] != null &&
          segments[2] != null) {
        return DateTime(segments[0]!, segments[1]!, segments[2]!, 8);
      }
    }
    return DateTime.now();
  }

  List<_RoadmapDay> _groupBlocksByDay(List<ExamDojoDailyBlock> blocks) {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    final grouped = <String, List<ExamDojoDailyBlock>>{};

    for (final block in blocks) {
      final date = _blockDate(block);
      if (!date.isAfter(cutoff)) continue;
      final key = _formatDateKey(date);
      final list = grouped.putIfAbsent(key, () => []);
      list.add(block);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries.map((entry) {
      final date = _parseDateKey(entry.key);
      entry.value.sort(
        (a, b) => _blockDate(a).compareTo(_blockDate(b)),
      );
      return _RoadmapDay(
        date: date,
        displayLabel: _formatDisplayLabel(date),
        blocks: entry.value,
      );
    }).toList();
  }

  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDateKey(String key) {
    final parts = key.split('-').map(int.tryParse).toList();
    if (parts.length == 3 &&
        parts[0] != null &&
        parts[1] != null &&
        parts[2] != null) {
      return DateTime(parts[0]!, parts[1]!, parts[2]!);
    }
    return DateTime.now();
  }

  String _formatDisplayLabel(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    final weekday = weekdays[(date.weekday - 1).clamp(0, 6)];
    final month = months[(date.month - 1).clamp(0, 11)];
    return '$weekday, $month ${date.day}';
  }

  void _startBlock(BuildContext context, ExamDojoDailyBlock block) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExamDojoBlockLauncher()
          .ensureStudyBlockFromRoadmap(block: block, dojoId: widget.dojo.id);
      if (mounted) {
        try {
          context.read<ExamDojoController>().retryDailyBlocks();
        } catch (_) {
          // Controller not available in this context; ignore.
        }
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Study block added to your schedule.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to start block: $error')),
      );
    }
  }

  Map<String, dynamic> _extractRoadmapPayload(
    Map<String, dynamic> snapshot,
  ) {
    const candidates = ['roadmap', 'plan', 'payload'];
    for (final key in candidates) {
      final nested = snapshot[key];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return snapshot;
  }

  Map<String, dynamic> _mapFrom(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (raw is Map) {
      final List<Map<String, dynamic>> result = [];
      raw.forEach((key, value) {
        if (value is List) {
          for (final entry in value.whereType<Map>()) {
            final map = Map<String, dynamic>.from(entry);
            map.putIfAbsent('date', () => key.toString());
            result.add(map);
          }
        } else if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          map.putIfAbsent('date', () => key.toString());
          result.add(map);
        }
      });
      return result;
    }
    return const <Map<String, dynamic>>[];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.metadata});

  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final studyStart = metadata['studyWindowStart']?.toString();
    final studyEnd = metadata['studyWindowEnd']?.toString();
    final weeklyMinutes = metadata['weeklyLoadMinutes'];
    final timezone = metadata['timezone']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study window',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              studyStart != null && studyEnd != null
                  ? '$studyStart → $studyEnd'
                  : 'Not available',
            ),
            const SizedBox(height: 12),
            Text(
              'Weekly load: '
              '${weeklyMinutes != null ? '$weeklyMinutes mins' : 'Not set'}',
            ),
            if (timezone != null) ...[
              const SizedBox(height: 4),
              Text('Timezone: $timezone'),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final _RoadmapWeek week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
          child: Text(
            week.week.toString(),
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        title: Text(week.focus),
        subtitle: week.notes != null ? Text(week.notes!) : null,
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone});

  final _RoadmapMilestone milestone;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(milestone.title),
        subtitle: Text(
          'Week ${milestone.targetWeek} • ${milestone.effortMinutes} mins • ${milestone.type}',
        ),
      ),
    );
  }
}

class _RevisionSlotChip extends StatelessWidget {
  const _RevisionSlotChip({required this.slot});

  final _RevisionSlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Week ${slot.week} · ${slot.minutes} mins · ${slot.subjectId ?? 'General'}',
      ),
    );
  }
}

class _RoadmapBlockCard extends StatelessWidget {
  const _RoadmapBlockCard({required this.block, required this.onStart});

  final ExamDojoDailyBlock block;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = block.date.isNotEmpty ? block.date : 'Scheduled';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  block.subjectName ?? 'Study block',
                  style: theme.textTheme.titleMedium,
                ),
                Text(dateLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              block.chapter ?? block.notes ?? 'Focus session',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('${block.blockType} • ${block.durationMinutes} mins'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onStart,
                child: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapDaySection extends StatelessWidget {
  const _RoadmapDaySection({required this.day, required this.onStart});

  final _RoadmapDay day;
  final void Function(ExamDojoDailyBlock block) onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.displayLabel,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...day.blocks.map(
            (block) => _RoadmapBlockCard(
              block: block,
              onStart: () => onStart(block),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapDay {
  const _RoadmapDay({
    required this.date,
    required this.displayLabel,
    required this.blocks,
  });

  final DateTime date;
  final String displayLabel;
  final List<ExamDojoDailyBlock> blocks;
}

class _RoadmapWeek {
  const _RoadmapWeek({required this.week, required this.focus, this.notes});

  final int week;
  final String focus;
  final String? notes;

  factory _RoadmapWeek.fromMap(Map<String, dynamic> map) {
    return _RoadmapWeek(
      week: (map['week'] as num?)?.toInt() ?? 0,
      focus: map['focus']?.toString() ?? 'Focus',
      notes: map['notes']?.toString(),
    );
  }
}

class _RoadmapMilestone {
  const _RoadmapMilestone({
    required this.id,
    required this.title,
    required this.targetWeek,
    required this.effortMinutes,
    required this.type,
  });

  final String id;
  final String title;
  final int targetWeek;
  final int effortMinutes;
  final String type;

  factory _RoadmapMilestone.fromMap(Map<String, dynamic> map) {
    return _RoadmapMilestone(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Milestone',
      targetWeek: (map['target_week'] as num?)?.toInt() ?? 0,
      effortMinutes: (map['effort_minutes'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'learn',
    );
  }
}

class _RevisionSlot {
  const _RevisionSlot({
    required this.week,
    required this.subjectId,
    required this.minutes,
  });

  final int week;
  final String? subjectId;
  final int minutes;

  factory _RevisionSlot.fromMap(Map<String, dynamic> map) {
    return _RevisionSlot(
      week: (map['week'] as num?)?.toInt() ?? 0,
      subjectId: map['subjectId']?.toString(),
      minutes: (map['minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class _RoadmapPayload {
  const _RoadmapPayload({
    required this.blocks,
    required this.metadata,
    required this.weeks,
    required this.milestones,
    required this.revisionSlots,
    this.version,
  });

  const _RoadmapPayload.empty()
      : blocks = const [],
        metadata = const {},
        weeks = const [],
        milestones = const [],
        revisionSlots = const [],
        version = null;

  final List<ExamDojoDailyBlock> blocks;
  final Map<String, dynamic> metadata;
  final List<_RoadmapWeek> weeks;
  final List<_RoadmapMilestone> milestones;
  final List<_RevisionSlot> revisionSlots;
  final String? version;
}
