import 'package:flutter/material.dart';
import 'package:study_sensei/features/friends/data/models/user_model.dart';

class FriendDetailScreen extends StatelessWidget {
  final UserModel friend;

  const FriendDetailScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 60,
                backgroundColor:
                    theme.primaryColor.withAlpha((0.1 * 255).round()),
                backgroundImage: _buildAvatarImage(),
                child: _buildAvatarImage() == null
                    ? Text(
                        friend.name.isNotEmpty
                            ? friend.name[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                friend.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                friend.email,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              _FriendInfoCard(
                title: 'Contact Info',
                children: [
                  _FriendInfoRow(
                    label: 'Email',
                    value: friend.email,
                    icon: Icons.email_outlined,
                  ),
                  if (friend.phone?.isNotEmpty == true)
                    _FriendInfoRow(
                      label: 'Phone',
                      value: friend.phone!,
                      icon: Icons.phone_outlined,
                    ),
                ],
              ),
              if (friend.createdAt != null) ...[
                const SizedBox(height: 16),
                _FriendInfoCard(
                  title: 'Friend Since',
                  children: [
                    _FriendInfoRow(
                      label: 'Added On',
                      value:
                          '${friend.createdAt!.day}/${friend.createdAt!.month}/${friend.createdAt!.year}',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ],
              if (friend.dateOfBirth != null ||
                  (friend.gender?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 16),
                _FriendInfoCard(
                  title: 'Personal Info',
                  children: [
                    if (friend.dateOfBirth != null)
                      _FriendInfoRow(
                        label: 'Date of Birth',
                        value: _formatDate(friend.dateOfBirth!),
                        icon: Icons.cake_outlined,
                      ),
                    if (friend.gender?.isNotEmpty ?? false)
                      _FriendInfoRow(
                        label: 'Gender',
                        value: friend.gender!,
                        icon: Icons.wc_outlined,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider<Object>? _buildAvatarImage() {
    final photoUrl = friend.photoUrl;
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    return NetworkImage(photoUrl);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _FriendInfoCard extends StatelessWidget {
  final String title;
  final List<_FriendInfoRow> children;

  const _FriendInfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FriendInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FriendInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
