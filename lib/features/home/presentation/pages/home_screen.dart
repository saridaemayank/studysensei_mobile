import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/providers/user_provider.dart';
import '../../../common/widgets/sensei_card.dart';
import '../../../sensei/models/sensei_session.dart';
import '../../../sensei/screens/sensei_image_flow.dart';
import '../../../sensei/screens/sensei_generate_screen.dart';
import '../../../sensei/services/sensei_api_service.dart';

/// Redesigned Home Screen.
/// Follows the product direction: "A smart study companion that helps you exactly when you get stuck."
/// Clean, spacious, and hero-driven:
/// 1. Greeting + Motivational line + Avatar
/// 2. "Stuck on something?" Sensei hero card
/// 3. "Continue where you left off" recent session preview (only if one exists)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _openCameraFlow(BuildContext context) async {
    await SenseiImageFlow.takePhoto(context);
  }

  void _openSession(BuildContext context, SenseiSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SenseiGenerateScreen.fromRouteArgs(session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    UserProvider? userProvider;
    try {
      userProvider = Provider.of<UserProvider?>(context);
    } catch (_) {
      userProvider = null;
    }
    final user = userProvider?.user;
    final userName =
        (userProvider?.userPreferences?.name?.trim().isNotEmpty ?? false)
            ? userProvider!.userPreferences!.name!.split(' ').first
            : (user?.displayName?.trim().isNotEmpty ?? false)
                ? user!.displayName!.split(' ').first
                : 'there';

    final photoUrl = userProvider?.userPreferences?.photoUrl ?? user?.photoURL;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER: Greeting, Motivation, Profile Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: AppTypography.pageTitle.copyWith(
                            fontSize: 28,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Keep going. You've got this.",
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      // Notification Icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Profile Avatar
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed('/profile');
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.borderMedium,
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        userName.isNotEmpty
                                            ? userName[0].toUpperCase()
                                            : 'S',
                                        style: AppTypography.button.copyWith(
                                          color: AppColors.primaryLight,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : 'S',
                                      style: AppTypography.button.copyWith(
                                        color: AppColors.primaryLight,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 2. MAIN HERO SECTION: "Stuck on something?" Sensei Card
              SenseiCard(
                onTap: () => _openCameraFlow(context),
                padding: const EdgeInsets.all(24),
                border: Border.all(
                  color: AppColors.borderActive,
                  width: 1.2,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF131D33),
                    Color(0xFF0C1424),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sparkle tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sensei',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Headline
                    Text(
                      'Stuck on something?',
                      style: AppTypography.pageTitle.copyWith(
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Take a photo. Get unstuck.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Visual Camera Action
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGlow,
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tap to capture',
                                style: AppTypography.cardTitle.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Textbook, notes, or working',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primaryLight.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 3. SECONDARY SECTION: "Continue where you left off"
              // Rendered ONLY if the student has a previous session
              if (user != null)
                StreamBuilder<List<SenseiSession>>(
                  stream: SenseiApiService(user: user).getUserSessions(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final recentSession = snapshot.data!.first;
                    final sessionTitle =
                        (recentSession.title?.isNotEmpty ?? false)
                            ? recentSession.title!
                            : (recentSession.concepts.isNotEmpty)
                                ? recentSession.concepts.first
                                : recentSession.subject;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Continue where you left off',
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SenseiCard(
                          onTap: () => _openSession(context, recentSession),
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.history_edu_rounded,
                                  color: AppColors.primaryLight,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sessionTitle,
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${recentSession.subject} • ${_formatTimeAgo(recentSession.createdAt)}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textTertiary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textTertiary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
