import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';

/// Presentation only; account actions are supplied by the authenticated screen.
class ProfileView extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final bool? notificationsEnabled;
  final bool isPhotoUpdating;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;
  final VoidCallback onChangePhoto;
  final Widget requests;

  const ProfileView({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    this.notificationsEnabled,
    this.isPhotoUpdating = false,
    required this.onEditProfile,
    required this.onSignOut,
    required this.onChangePhoto,
    required this.requests,
  });

  void _about(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
                header: true,
                child:
                    const Text('StudySensei', style: AppTypography.pageTitle)),
            const SizedBox(height: 12),
            const Text('Show. Understand. Learn.',
                style: AppTypography.bodyLarge),
            const SizedBox(height: 12),
            // Matches the app version in pubspec.yaml; no additional plugin.
            const Text('Version 1.0.0', style: AppTypography.bodyMedium),
            const SizedBox(height: 24),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Semantics(
                header: true,
                child: const Text('Profile', style: AppTypography.pageTitle)),
            const SizedBox(height: 28),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    margin: const EdgeInsets.only(bottom: 8, right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceHighlight,
                      border: Border.all(color: AppColors.borderActive),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl != null && photoUrl!.isNotEmpty
                        ? Image.network(photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.person_outline,
                                size: 48,
                                color: AppColors.primaryLight))
                        : const Icon(Icons.person_outline,
                            size: 48, color: AppColors.primaryLight),
                  ),
                  Material(
                    color: AppColors.surfaceHighlight,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Update profile photo',
                      onPressed: isPhotoUpdating ? null : onChangePhoto,
                      icon: isPhotoUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_outlined,
                              color: AppColors.primaryLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(name.trim().isEmpty ? 'Sensei Learner' : name,
                textAlign: TextAlign.center, style: AppTypography.pageTitle),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(email,
                  textAlign: TextAlign.center, style: AppTypography.bodyMedium),
            ],
            if (notificationsEnabled != null) ...[
              const _GroupHeading('STUDY'),
              SenseiCard(
                child: _SettingContent(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  description:
                      'Saved preference: ${notificationsEnabled! ? 'enabled' : 'disabled'}',
                ),
              ),
            ],
            const _GroupHeading('APP'),
            SenseiCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.people_outline,
                    color: AppColors.primaryLight),
                title: const Text('Friend requests',
                    style: AppTypography.cardTitle),
                children: [requests],
              ),
            ),
            const SizedBox(height: 12),
            _SettingRow(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => _about(context)),
            const _GroupHeading('ACCOUNT'),
            _SettingRow(
                icon: Icons.person_outline,
                title: 'Edit profile',
                onTap: onEditProfile),
            const SizedBox(height: 12),
            _SettingRow(
                icon: Icons.logout, title: 'Sign out', onTap: onSignOut),
          ],
        ),
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  final String text;
  const _GroupHeading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Semantics(
            header: true,
            child: Text(text,
                style: AppTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600, letterSpacing: 1))),
      );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingRow(
      {required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: SenseiCard(
            onTap: onTap,
            child: _SettingContent(icon: icon, title: title, actionable: true)),
      );
}

class _SettingContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool actionable;
  const _SettingContent(
      {required this.icon,
      required this.title,
      this.description,
      this.actionable = false});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.primaryLight),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: AppTypography.cardTitle),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: AppTypography.bodyMedium)
                ],
              ])),
          if (actionable) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary)
          ],
        ],
      );
}
