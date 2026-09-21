import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/pages/phone_verification_screen.dart';
import '../../auth/providers/user_provider.dart';
import '../../common/widgets/sensei_card.dart';
import '../../common/widgets/sensei_primary_button.dart';
import 'sensei_image_flow.dart';
import '../models/sensei_mode.dart';
import '../models/sensei_session.dart';
import '../widgets/sensei_mode_switch.dart';
import '../services/sensei_api_service.dart';
import 'sensei_capture_screen.dart';
import 'sensei_generate_screen.dart';

/// One Sensei entry point for focused Doubt and exploratory Explain.
class SenseiLandingScreen extends StatefulWidget {
  const SenseiLandingScreen({super.key});

  @override
  State<SenseiLandingScreen> createState() => _SenseiLandingScreenState();
}

class _SenseiLandingScreenState extends State<SenseiLandingScreen> {
  bool _openingImage = false;

  Future<void> _onTakePhoto({String concept = 'Doubt'}) async {
    if (_openingImage) return;
    _openingImage = true;
    try {
      // Get Help returns SenseiHelpRequest here for the future Phase 6 flow.
      await SenseiImageFlow.takePhoto(context, concept: concept);
    } finally {
      _openingImage = false;
    }
  }

  Widget _buildPhoneVerificationRequired() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sensei'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify your phone number',
                style: AppTypography.pageTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 12),
              Text(
                'A verified phone number keeps StudySensei safe and ensures your learning history stays secure.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 32),
              SenseiPrimaryButton(
                text: 'Verify Phone Number',
                onPressed: () async {
                  await Navigator.of(context)
                      .pushNamed(PhoneVerificationScreen.routeName);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  final TextEditingController _explainTopic = TextEditingController();
  SenseiMode _mode = SenseiMode.doubt;
  Stream<List<SenseiSession>>? _sessions;
  String? _sessionsUserId;

  @override
  void dispose() {
    _explainTopic.dispose();
    super.dispose();
  }

  Future<void> _explainVideo() async {
    if (_openingImage) return;
    if (_explainTopic.text.trim().isEmpty) {
      if (!await _describeTopic() || !mounted) return;
    }
    final topic = _explainTopic.text.trim();
    FocusScope.of(context).unfocus();
    _openingImage = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SenseiCaptureScreen(subject: 'General', concept: topic),
      ));
    } finally {
      _openingImage = false;
    }
  }

  bool _editingTopic = false;

  Future<bool> _describeTopic() async {
    if (_editingTopic || _openingImage) return false;
    _editingTopic = true;
    try {
      return await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (sheetContext) => SafeArea(
                child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Describe Topic',
                              style: AppTypography.sectionTitle)),
                      IconButton(
                          tooltip: 'Close',
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          icon: const Icon(Icons.close_rounded)),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Tell Sensei what you want to understand.',
                        style: AppTypography.bodyMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _explainTopic,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                          labelText: 'Topic or concept',
                          hintText: 'e.g. Reflection of light'),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _explainTopic,
                      builder: (context, value, _) => SenseiPrimaryButton(
                          text: 'Continue',
                          onPressed: value.text.trim().isEmpty
                              ? null
                              : () => Navigator.of(sheetContext).pop(true)),
                    ),
                  ]),
            )),
          ) ??
          false;
    } finally {
      _editingTopic = false;
    }
  }

  // Reserve the same text space in both modes, including at larger text scales.
  // Only visible copy is rendered and exposed to accessibility services.
  Widget _modeText(String doubtText, String explainText, TextStyle style,
          {TextAlign textAlign = TextAlign.start}) =>
      LayoutBuilder(builder: (context, constraints) {
        double height = 0;
        for (final text in [doubtText, explainText]) {
          final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context))
            ..layout(maxWidth: constraints.maxWidth);
          if (painter.height > height) height = painter.height;
          painter.dispose();
        }
        return SizedBox(
            height: height,
            child: Text(_mode == SenseiMode.doubt ? doubtText : explainText,
                style: style, textAlign: textAlign));
      });

  Widget _action(
      {required String doubtTitle,
      required String explainTitle,
      required IconData icon,
      required VoidCallback? onTap}) {
    final accent =
        _mode == SenseiMode.doubt ? AppColors.primary : AppColors.info;
    return Semantics(
      label: _mode == SenseiMode.doubt ? doubtTitle : explainTitle,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: SenseiCard(
        key: const ValueKey('sensei-action-0'),
        onTap: onTap,
        padding: const EdgeInsets.all(24),
        border: Border.all(color: accent.withValues(alpha: .65), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                accent.withValues(alpha: .28), AppColors.surfaceElevated),
            AppColors.surface
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 260),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: .25), blurRadius: 32)
                  ],
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 46),
              ),
              const SizedBox(height: 24),
              _modeText('Stuck on something?', 'Curious about something?',
                  AppTypography.sectionTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              _modeText(
                  'Take a photo. Get unstuck.',
                  'Record a video. Explore it.',
                  AppTypography.bodyMedium.copyWith(fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider?>();
    if (userProvider?.isAuthenticated == true &&
        userProvider?.userPreferences?.phoneVerified != true) {
      return _buildPhoneVerificationRequired();
    }
    final user = userProvider?.user;
    if (_sessionsUserId != user?.uid) {
      _sessionsUserId = user?.uid;
      _sessions =
          user == null ? null : SenseiApiService(user: user).getUserSessions();
    }
    final doubt = _mode == SenseiMode.doubt;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final profileName = userProvider?.userPreferences?.name?.trim();
    final displayName = profileName?.isNotEmpty == true
        ? profileName!
        : user?.displayName?.trim();
    final name = displayName?.isNotEmpty == true
        ? displayName!.split(RegExp(r'\s+')).first
        : 'Learner';
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 20),
          Text('$greeting,',
              style: AppTypography.bodyLarge
                  .copyWith(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(name,
              key: const ValueKey('sensei-user-name'),
              style: AppTypography.pageTitle.copyWith(fontSize: 36)),
          const SizedBox(height: 12),
          Text('“Keep going. You’ve got this.”',
              style: AppTypography.bodyMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 28),
          SenseiModeSwitch(
              value: _mode,
              onChanged: (mode) {
                if (!_openingImage) setState(() => _mode = mode);
              }),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, .025), end: Offset.zero)
                        .animate(animation),
                    child: child)),
            child: Column(
                key: ValueKey(_mode),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _action(
                      doubtTitle: 'Take Photo',
                      explainTitle: 'Record Video',
                      icon: doubt
                          ? Icons.camera_alt_rounded
                          : Icons.videocam_rounded,
                      onTap: doubt ? _onTakePhoto : () => _explainVideo()),
                ]),
          ),
          if (_sessions != null)
            StreamBuilder<List<SenseiSession>>(
              stream: _sessions,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                final session = snapshot.data!.first;
                return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Continue where you left off',
                              style: AppTypography.cardTitle),
                          const SizedBox(height: 12),
                          SenseiCard(
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          SenseiGenerateScreen.fromRouteArgs(
                                              session))),
                              child: Text(session.title ?? session.subject,
                                  style: AppTypography.bodyLarge)),
                        ]));
              },
            ),
        ]),
      )),
    );
  }
}
