import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/groups/data/models/dojo_announcement.dart';
import 'package:study_sensei/features/groups/data/models/dojo_pin.dart';
import 'package:study_sensei/features/groups/data/services/dojo_engagement_service.dart';

class DojoEngagementPanel extends StatelessWidget {
  const DojoEngagementPanel({super.key, required this.dojoId});
  final String dojoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<List<DojoPin>>(
          stream: DojoEngagementService().watchPins(dojoId),
          builder: (context, snapshot) {
            final pins = snapshot.data ?? const <DojoPin>[];
            if (pins.isEmpty) return const SizedBox.shrink();
            return InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => _PinsSheet(pins: pins),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.surface,
                child: Text('${pins.length} pinned items',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.primaryLight)),
              ),
            );
          },
        ),
        StreamBuilder<List<DojoAnnouncement>>(
          stream: DojoEngagementService().watchAnnouncements(dojoId),
          builder: (context, snapshot) {
            final announcements = snapshot.data ?? const <DojoAnnouncement>[];
            if (announcements.isEmpty) return const SizedBox.shrink();
            final item = announcements.first;
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.campaign_rounded, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle),
                      Text(item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium),
                    ])),
              ]),
            );
          },
        ),
      ],
    );
  }
}

class _PinsSheet extends StatelessWidget {
  const _PinsSheet({required this.pins});
  final List<DojoPin> pins;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Pinned items', style: AppTypography.sectionTitle),
            ...pins.map((pin) => ListTile(
                  leading: const Icon(Icons.push_pin_rounded),
                  title: Text(pin.type.name),
                  subtitle: Text(
                      pin.preview ?? 'This item is no longer available',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                )),
          ],
        ),
      );
}
