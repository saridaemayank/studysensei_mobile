import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/features/onboarding/data/onboarding_item.dart';
import 'package:study_sensei/features/onboarding/data/onboarding_storage.dart';
import 'package:study_sensei/features/onboarding/presentation/widgets/onboarding_action_buttons.dart';
import 'package:study_sensei/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:study_sensei/features/onboarding/presentation/widgets/onboarding_progress_indicator.dart';
import 'package:study_sensei/features/routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  final OnboardingStorage storage;
  final bool showAuthChoices;

  const OnboardingScreen({
    super.key,
    this.storage = const OnboardingStorage(),
    this.showAuthChoices = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isFinishing = false;

  bool get _isFinalPage => onboardingItems[_currentIndex].isFinalPage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.showAuthChoices ? onboardingItems.length - 1 : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _continue() {
    final next = (_currentIndex + 1).clamp(0, onboardingItems.length - 1);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _skipToFinalPage() {
    _pageController.animateToPage(
      onboardingItems.length - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish(String routeName) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await widget.storage.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isFinalPage ? 0 : 1,
                  child: TextButton(
                    onPressed: _isFinalPage ? null : _skipToFinalPage,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: OnboardingPageView(
                controller: _pageController,
                currentIndex: _currentIndex,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Column(
                children: [
                  OnboardingProgressIndicator(
                    currentIndex: _currentIndex,
                    itemCount: onboardingItems.length,
                  ),
                  const SizedBox(height: 22),
                  OnboardingActionButtons(
                    isFinalPage: _isFinalPage,
                    onContinue: _continue,
                    onSkip: _skipToFinalPage,
                    onCreateAccount: _isFinishing
                        ? () {}
                        : () => _finish(AppRoutes.register),
                    onSignIn:
                        _isFinishing ? () {} : () => _finish(AppRoutes.login),
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
