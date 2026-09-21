import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';
import 'package:study_sensei/features/groups/data/models/dojo_announcement.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/services/dojo_engagement_service.dart';

class DojoAnnouncementsScreen extends StatelessWidget {
  const DojoAnnouncementsScreen({
    super.key,
    required this.group,
    this.service,
  });

  final Group group;
  final DojoEngagementService? service;

  DojoEngagementService get _service => service ?? DojoEngagementService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Announcements')),
      body: StreamBuilder<List<DojoAnnouncement>>(
        stream: _service.watchAnnouncements(group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Couldn't load announcements right now."),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final announcements = snapshot.data ?? const <DojoAnnouncement>[];
          if (announcements.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: announcements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Semantics(
                button: true,
                label: 'Announcement: ${announcement.title}',
                child: SenseiCard(
                  onTap: () => _showAnnouncement(context, announcement),
                  padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child:
                            Icon(Icons.campaign_rounded, color: AppColors.info),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(announcement.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cardTitle),
                            const SizedBox(height: 5),
                            Text(announcement.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Posted by ${announcement.createdByName} · ${_dateLabel(announcement.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete announcement',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _confirmDelete(context, announcement),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAnnouncement(
    BuildContext context,
    DojoAnnouncement announcement,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign_rounded, color: AppColors.info),
                const SizedBox(height: 14),
                Text(announcement.title, style: AppTypography.sectionTitle),
                const SizedBox(height: 12),
                SelectableText(announcement.body,
                    style: AppTypography.bodyLarge),
                const SizedBox(height: 16),
                Text(
                  'Posted by ${announcement.createdByName} · ${_dateLabel(announcement.createdAt)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DojoAnnouncement announcement,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete announcement?'),
        content:
            const Text('This will remove the announcement from this Dojo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true || !context.mounted) return;
    try {
      await _service.deleteAnnouncement(group: group, id: announcement.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete this announcement.")),
      );
    }
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
