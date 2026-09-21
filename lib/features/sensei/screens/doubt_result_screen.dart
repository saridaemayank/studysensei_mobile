import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/sensei_card.dart';
import '../../common/widgets/sensei_primary_button.dart';
import '../models/sensei_doubt_response.dart';
import '../models/sensei_help_mode.dart';
import '../models/sensei_help_request.dart';
import '../widgets/sensei_result_preview.dart';

class DoubtResultScreen extends StatelessWidget {
  final SenseiDoubtResponse response;
  final SenseiHelpRequest request;
  final VoidCallback onTryAnother;
  const DoubtResultScreen(
      {super.key,
      required this.response,
      required this.request,
      required this.onTryAnother});

  bool _present(String? value) => value != null && value.trim().isNotEmpty;
  Color get _accent {
    if (response.inputStatus != DoubtInputStatus.readable) {
      return AppColors.warning;
    }
    if (response.mode == SenseiHelpMode.hint) return AppColors.warning;
    if (response.mode == SenseiHelpMode.explain ||
        response.workStatus == DoubtWorkStatus.correct) {
      return AppColors.success;
    }
    return response.workStatus == DoubtWorkStatus.mistakeFound
        ? AppColors.error
        : AppColors.warning;
  }

  String get _modeLabel => switch (response.mode) {
        SenseiHelpMode.explain => 'EXPLAIN',
        SenseiHelpMode.checkWork => 'CHECK MY WORK',
        SenseiHelpMode.hint => 'HINT',
      };
  String? get _inputMessage => switch (response.inputStatus) {
        DoubtInputStatus.readable => response.mode ==
                    SenseiHelpMode.checkWork &&
                response.workStatus == DoubtWorkStatus.unclear
            ? 'Try a closer photo, a smaller selected area, or clearer working.'
            : null,
        DoubtInputStatus.unreadable =>
          'Try a closer photo or select a smaller, clearer area.',
        DoubtInputStatus.emptyRegion =>
          'Select the part containing your question or working.',
        DoubtInputStatus.missingContext =>
          'Include the question and a little more of your working.',
        DoubtInputStatus.unsupported =>
          'Try a photo of a question, note, or diagram Sensei can help with.',
      };
  String get _hero {
    if (response.inputStatus != DoubtInputStatus.readable) {
      return switch (response.inputStatus) {
        DoubtInputStatus.unreadable => "I couldn't read this clearly",
        DoubtInputStatus.emptyRegion => "Let's select your question",
        DoubtInputStatus.missingContext => 'I need a little more context',
        _ => "Let's try another question",
      };
    }
    return switch (response.mode) {
      SenseiHelpMode.explain => 'Why this works',
      SenseiHelpMode.hint => "Here's a hint",
      SenseiHelpMode.checkWork => switch (response.workStatus) {
          DoubtWorkStatus.correct => 'Your work looks correct',
          DoubtWorkStatus.mistakeFound => "Here's where it goes wrong",
          DoubtWorkStatus.incomplete => 'I need a little more working',
          _ => "I couldn't read this clearly",
        },
    };
  }

  String? get _mistakeLabel => switch (response.mistakeType) {
        DoubtMistakeType.conceptual => 'Concept',
        DoubtMistakeType.formula => 'Formula',
        DoubtMistakeType.algebra => 'Algebra',
        DoubtMistakeType.arithmetic => 'Arithmetic',
        DoubtMistakeType.assumption => 'Assumption',
        DoubtMistakeType.notation => 'Notation',
        _ => null,
      };
  Widget _heading(String text, TextStyle style) =>
      Semantics(header: true, child: Text(text, style: style));
  Widget _section(String label, String? text,
      {bool formula = false, bool prominent = false}) {
    if (!_present(text)) return const SizedBox.shrink();
    final body = SelectableText(text!,
        style: AppTypography.bodyLarge.copyWith(
            height: 1.65,
            fontSize: prominent ? 20 : 16,
            fontFamily: formula ? 'monospace' : AppTypography.bodyFont));
    return Padding(
        padding: const EdgeInsets.only(top: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(label, AppTypography.cardTitle),
          const SizedBox(height: 8),
          if (formula)
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: _accent, width: 3))),
                child: body)
          else
            body,
        ]));
  }

  List<Widget> get _content {
    if (response.inputStatus != DoubtInputStatus.readable) {
      return [
        _section(
            'What I can see',
            response.mode == SenseiHelpMode.hint
                ? response.hint
                : response.explanation),
        _section('Try this next', response.nextAction)
      ];
    }
    return switch (response.mode) {
      SenseiHelpMode.explain => [
          _section('Explanation', response.explanation),
          _section('Concept', response.concept),
          _section('Key idea', response.keyIdea),
          _section('Try this next', response.nextAction),
        ],
      // Hint-only presentation deliberately excludes explanation and work fields.
      SenseiHelpMode.hint => [
          _section(
              'Hint${response.hintLevel == null ? '' : ' ${response.hintLevel}'}',
              response.hint,
              prominent: true)
        ],
      SenseiHelpMode.checkWork => switch (response.workStatus) {
          DoubtWorkStatus.mistakeFound => [
              if (_mistakeLabel != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                            label: Text(_mistakeLabel!),
                            backgroundColor: AppColors.surfaceHighlight))),
              _section('Mistake', response.mistake),
              _section('Why', response.explanation),
              _section('Corrected step', response.correctedStep, formula: true),
              _section('Next step', response.nextAction),
            ],
          DoubtWorkStatus.correct => [
              _section('Why it checks out', response.explanation),
              _section('Keep going', response.nextAction)
            ],
          _ => [
              _section('What I can see', response.explanation),
              _section('Try this next', response.nextAction)
            ],
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final topic = response.topic.trim();
    final showTopic = topic.isNotEmpty &&
        !['unknown', 'other', 'n/a'].contains(topic.toLowerCase());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: const BackButton(),
          title: Text(_modeLabel,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.2))),
      body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      response.subject.trim().isEmpty ||
                              response.subject.toLowerCase() == 'other'
                          ? 'Your question'
                          : response.subject,
                      style: AppTypography.bodyMedium),
                  if (showTopic) ...[
                    const SizedBox(height: 6),
                    _heading(topic, AppTypography.pageTitle)
                  ],
                  SenseiResultPreview(
                      selection: request.imageSelection, accent: _accent),
                  const SizedBox(height: 24),
                  SenseiCard(
                      border: Border.all(color: _accent.withValues(alpha: .3)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: _accent.withValues(alpha: .12),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(
                                        response.mode == SenseiHelpMode.hint
                                            ? Icons.tips_and_updates_outlined
                                            : response.mode ==
                                                    SenseiHelpMode.checkWork
                                                ? Icons.fact_check_outlined
                                                : Icons
                                                    .lightbulb_outline_rounded,
                                        color: _accent))),
                            const SizedBox(height: 16),
                            _heading(
                                _hero,
                                AppTypography.sectionTitle
                                    .copyWith(fontSize: 24)),
                            // Hint titles are omitted because only the hint is intended for display.
                            if (response.mode != SenseiHelpMode.hint &&
                                _present(response.title)) ...[
                              const SizedBox(height: 8),
                              SelectableText(response.title,
                                  style: AppTypography.bodyMedium)
                            ],
                            if (_inputMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(_inputMessage!,
                                  style: AppTypography.bodyMedium)
                            ],
                            ..._content,
                          ])),
                ],
              ))),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SenseiPrimaryButton(
                    text: 'Ask a follow-up',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => DoubtFollowUpPlaceholder(
                                request: request, response: response)))),
                const SizedBox(height: 4),
                TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight),
                    onPressed: onTryAnother,
                    child: const Text('Try another doubt')),
              ]))),
    );
  }
}

/// Context-only handoff for Phase 9. No input, network calls, or persistence.
class DoubtFollowUpPlaceholder extends StatelessWidget {
  final SenseiHelpRequest request;
  final SenseiDoubtResponse response;
  const DoubtFollowUpPlaceholder(
      {super.key, required this.request, required this.response});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Ask a follow-up')),
      body: const SafeArea(
          child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Follow-up questions are coming next.',
                        style: AppTypography.sectionTitle),
                    SizedBox(height: 12),
                    Text(
                        'Your question and this explanation are ready for the next step. Follow-up chat is planned for Phase 9.',
                        style: AppTypography.bodyLarge),
                  ]))));
}
