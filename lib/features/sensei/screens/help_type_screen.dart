import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/sensei_card.dart';
import '../../common/widgets/sensei_primary_button.dart';
import '../models/academic_level.dart';
import '../models/sensei_help_mode.dart';
import '../models/sensei_help_request.dart';
import '../models/sensei_image_selection.dart';

/// Returns a request on Get Help; Back returns null to the intact selector.
class HelpTypeScreen extends StatefulWidget {
  final SenseiImageSelection imageSelection;
  final AcademicLevel initialAcademicLevel;

  const HelpTypeScreen({
    super.key,
    required this.imageSelection,
    this.initialAcademicLevel = AcademicLevel.boards,
  });

  @override
  State<HelpTypeScreen> createState() => _HelpTypeScreenState();
}

class _HelpTypeScreenState extends State<HelpTypeScreen> {
  SenseiHelpMode? _mode;
  late AcademicLevel _level = widget.initialAcademicLevel;
  bool _submitted = false;

  void _getHelp() {
    if (_mode == null || _submitted) return;
    setState(() => _submitted = true);
    Navigator.of(context).pop(SenseiHelpRequest(
      imageSelection: widget.imageSelection,
      mode: _mode!,
      academicLevel: _level,
    ));
  }

  Widget _modeCard(SenseiHelpMode mode) {
    final selected = _mode == mode;
    final accent = switch (mode) {
      SenseiHelpMode.explain => AppColors.success,
      SenseiHelpMode.checkWork => AppColors.error,
      SenseiHelpMode.hint => AppColors.warning,
    };
    final icon = switch (mode) {
      SenseiHelpMode.explain => Icons.lightbulb_outline_rounded,
      SenseiHelpMode.checkWork => Icons.fact_check_outlined,
      SenseiHelpMode.hint => Icons.tips_and_updates_outlined,
    };
    void choose() => setState(() => _mode = mode);
    return Semantics(
      label: '${mode.displayTitle}. ${mode.description}',
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: _submitted ? null : choose,
      excludeSemantics: true,
      child: SenseiCard(
        onTap: _submitted ? null : choose,
        padding: const EdgeInsets.all(16),
        backgroundColor: selected
            ? Color.alphaBlend(
                accent.withValues(alpha: .06), AppColors.surfaceElevated)
            : AppColors.surfaceElevated,
        border: Border.all(
            color: selected
                ? accent.withValues(alpha: .7)
                : AppColors.borderSubtle,
            width: 1.5),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: selected ? .16 : .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(mode.displayTitle, style: AppTypography.cardTitle),
                const SizedBox(height: 4),
                Text(mode.description, style: AppTypography.bodyMedium),
              ])),
          const SizedBox(width: 8),
          SizedBox(
              width: 20,
              child: selected
                  ? Icon(Icons.check_circle_rounded, color: accent, size: 20)
                  : null),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(children: [
                IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(width: 4),
                const Expanded(
                    child: Text('What do you need?',
                        style: AppTypography.sectionTitle)),
              ])),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Choose how Sensei should help.',
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: 20),
                  for (final mode in SenseiHelpMode.values) ...[
                    _modeCard(mode),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  const Text('Explanation level',
                      style: AppTypography.bodyLarge),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final level in AcademicLevel.values)
                      Expanded(
                          child: Padding(
                        padding: EdgeInsets.only(
                            right: level == AcademicLevel.jee ? 0 : 8),
                        child: Semantics(
                          label: level.displayTitle,
                          button: true,
                          excludeSemantics: true,
                          onTap: _submitted
                              ? null
                              : () => setState(() => _level = level),
                          selected: _level == level,
                          inMutuallyExclusiveGroup: true,
                          child: OutlinedButton(
                            onPressed: _submitted
                                ? null
                                : () => setState(() => _level = level),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                              foregroundColor: _level == level
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              backgroundColor: _level == level
                                  ? AppColors.primary.withValues(alpha: .2)
                                  : AppColors.surface,
                              side: BorderSide(
                                  color: _level == level
                                      ? AppColors.primaryLight
                                      : AppColors.borderSubtle),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(level.displayTitle,
                                      style: const TextStyle(fontSize: 14)),
                                  if (_level == level)
                                    const Icon(Icons.check_rounded, size: 14),
                                ]),
                          ),
                        ),
                      )),
                  ]),
                ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SenseiPrimaryButton(
                text: 'Get Help',
                height: 52,
                onPressed: _mode == null || _submitted ? null : _getHelp),
          ),
        ])),
      );
}
