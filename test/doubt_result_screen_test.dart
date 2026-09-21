import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/sensei/models/sensei_doubt_response.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_mode.dart';
import 'package:study_sensei/features/sensei/models/sensei_mode.dart';
import 'package:study_sensei/features/sensei/screens/doubt_result_screen.dart';
import 'package:study_sensei/features/sensei/screens/doubt_processing_screen.dart';
import 'package:study_sensei/features/sensei/screens/sensei_landing_screen.dart';
import 'package:study_sensei/features/sensei/screens/sensei_image_flow.dart';
import 'package:study_sensei/features/sensei/screens/select_area_screen.dart';
import 'package:study_sensei/features/sensei/widgets/sensei_mode_switch.dart';
import 'package:study_sensei/features/sensei/widgets/sensei_result_preview.dart';
import 'package:study_sensei/features/common/layouts/main_layout.dart';
import 'package:study_sensei/features/common/widgets/sensei_bottom_navigation.dart';
import 'sensei_doubt_api_test.dart' show input, reply;
import 'doubt_processing_screen_test.dart' show FakeDoubtApi;
import 'select_area_screen_test.dart' show waitForImage;

// Presentation fixture permits edge values without relaxing production parsing.
class ResultFixture implements SenseiDoubtResponse {
  @override
  final SenseiHelpMode mode;
  @override
  final String subject, topic, title, explanation;
  @override
  final String? concept, keyIdea, nextAction, mistake, correctedStep, hint;
  @override
  final DoubtWorkStatus? workStatus;
  @override
  final DoubtMistakeType? mistakeType;
  @override
  final DoubtInputStatus inputStatus;
  @override
  final int? hintLevel;
  @override
  int get version => 1;
  @override
  double get confidence => .8;
  const ResultFixture(
      {this.mode = SenseiHelpMode.explain,
      this.subject = 'Physics',
      this.topic = 'Current Electricity',
      this.title = 'A useful next step',
      this.explanation = 'V = I × R\nResistance is measured in Ω.',
      this.concept,
      this.keyIdea,
      this.nextAction,
      this.mistake,
      this.correctedStep,
      this.hint,
      this.workStatus,
      this.mistakeType,
      this.inputStatus = DoubtInputStatus.readable,
      this.hintLevel});
}

Finder selectedText(String value) =>
    find.byWidgetPredicate((w) => w is SelectableText && w.data == value);
Future<void> showResult(WidgetTester tester, SenseiDoubtResponse response,
    {Size size = const Size(412, 915), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: DoubtResultScreen(
          response: response,
          request: input(mode: response.mode),
          onTryAnother: () {})));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Explain renders selectable title, explanation and present sections',
      (tester) async {
    await showResult(
        tester,
        const ResultFixture(
            concept: 'Ohm’s law',
            keyIdea: 'Current depends on resistance.',
            nextAction: 'Find the current.'));
    expect(find.text('EXPLAIN'), findsOneWidget);
    expect(find.text('Why this works'), findsOneWidget);
    expect(selectedText('A useful next step'), findsOneWidget);
    expect(selectedText('V = I × R\nResistance is measured in Ω.'),
        findsOneWidget);
    expect(find.text('Concept'), findsOneWidget);
    expect(find.text('Key idea'), findsOneWidget);
    expect(find.text('Try this next'), findsOneWidget);
    expect(find.byType(SenseiResultPreview), findsOneWidget);
    expect(find.textContaining('Confidence'), findsNothing);
  });
  for (final missing in ['concept', 'keyIdea', 'nextAction']) {
    testWidgets('Explain omits absent $missing section', (tester) async {
      await showResult(
          tester,
          ResultFixture(
              concept: missing == 'concept' ? null : 'Concept body',
              keyIdea: missing == 'keyIdea' ? null : 'Key body',
              nextAction: missing == 'nextAction' ? null : 'Next body'));
      expect(
          find.text({
            'concept': 'Concept',
            'keyIdea': 'Key idea',
            'nextAction': 'Try this next'
          }[missing]!),
          findsNothing);
      expect(find.text('null'), findsNothing);
    });
  }
  for (final status in DoubtWorkStatus.values) {
    testWidgets('Check work presents ${status.name} constructively',
        (tester) async {
      await showResult(
          tester,
          ResultFixture(
              mode: SenseiHelpMode.checkWork,
              workStatus: status,
              mistake: status == DoubtWorkStatus.mistakeFound
                  ? 'The sign changed.'
                  : null,
              correctedStep:
                  status == DoubtWorkStatus.mistakeFound ? 'x = −2 × π' : null,
              nextAction: 'Continue from here.',
              mistakeType: DoubtMistakeType.algebra));
      expect(
          find.text(switch (status) {
            DoubtWorkStatus.correct => 'Your work looks correct',
            DoubtWorkStatus.mistakeFound => "Here's where it goes wrong",
            DoubtWorkStatus.incomplete => 'I need a little more working',
            DoubtWorkStatus.unclear => "I couldn't read this clearly"
          }),
          findsOneWidget);
      if (status == DoubtWorkStatus.mistakeFound) {
        expect(selectedText('The sign changed.'), findsOneWidget);
        expect(selectedText('x = −2 × π'), findsOneWidget);
        expect(find.text('Corrected step'), findsOneWidget);
        expect(find.text('Algebra'), findsOneWidget);
      } else {
        expect(find.text('Mistake'), findsNothing);
        expect(find.text('Corrected step'), findsNothing);
      }
    });
  }
  for (final type in DoubtMistakeType.values) {
    testWidgets('Mistake type ${type.name} has an appropriate label',
        (tester) async {
      await showResult(
          tester,
          ResultFixture(
              mode: SenseiHelpMode.checkWork,
              workStatus: DoubtWorkStatus.mistakeFound,
              mistakeType: type));
      expect(
          find.byType(Chip),
          type == DoubtMistakeType.none || type == DoubtMistakeType.other
              ? findsNothing
              : findsOneWidget);
    });
  }
  testWidgets('Hint shows only intended hint content', (tester) async {
    await showResult(
        tester,
        const ResultFixture(
            mode: SenseiHelpMode.hint,
            hint: 'Look for a common factor.',
            hintLevel: 1,
            explanation: 'Do not reveal explanation',
            mistake: 'Do not reveal mistake',
            correctedStep: 'Do not reveal answer',
            nextAction: 'Do not reveal next step'));
    expect(find.text("Here's a hint"), findsOneWidget);
    expect(find.text('Hint 1'), findsOneWidget);
    expect(selectedText('Look for a common factor.'), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is SelectableText &&
            (w.data?.contains('Do not reveal') ?? false)),
        findsNothing);
    expect(find.text('Another hint'), findsNothing);
  });
  for (final topic in ['', 'unknown']) {
    testWidgets('Missing topic "$topic" and optional sections are hidden',
        (tester) async {
      await showResult(tester, ResultFixture(subject: 'Other', topic: topic));
      expect(find.text('Your question'), findsOneWidget);
      expect(find.text('Concept'), findsNothing);
      expect(find.text('Key idea'), findsNothing);
      expect(find.text('Try this next'), findsNothing);
      if (topic.isNotEmpty) expect(find.text(topic), findsNothing);
    });
  }
  for (final status
      in DoubtInputStatus.values.where((s) => s != DoubtInputStatus.readable)) {
    testWidgets('Limited input ${status.name} gets useful guidance',
        (tester) async {
      await showResult(
          tester,
          ResultFixture(
              inputStatus: status, nextAction: 'Include the full question.'));
      expect(find.text('Why this works'), findsNothing);
      expect(find.text(status.apiValue), findsNothing);
      expect(selectedText('Include the full question.'), findsOneWidget);
    });
  }
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Long working and topic fit $size at $scale text',
          (tester) async {
        await showResult(
            tester,
            ResultFixture(
                mode: SenseiHelpMode.checkWork,
                workStatus: DoubtWorkStatus.mistakeFound,
                topic:
                    'Differentiation of a composite function with several terms ' *
                        5,
                explanation: 'Use the chain rule. Ω π → × √\n' * 60,
                correctedStep: 'dy/dx = 2x + √x → ' * 30,
                nextAction: 'Now try the next line.'),
            size: size,
            scale: scale);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(selectedText('Now try the next line.'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Ask a follow-up').hitTestable(), findsOneWidget);
        expect(find.text('Try another doubt').hitTestable(), findsOneWidget);
      });
    }
  }
  testWidgets('Follow-up placeholder retains the exact request and result',
      (tester) async {
    await showResult(tester, const ResultFixture());
    final result =
        tester.widget<DoubtResultScreen>(find.byType(DoubtResultScreen));
    await tester.tap(find.text('Ask a follow-up'));
    await tester.pumpAndSettle();
    final follow = tester.widget<DoubtFollowUpPlaceholder>(
        find.byType(DoubtFollowUpPlaceholder));
    expect(follow.request, same(result.request));
    expect(follow.response, same(result.response));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DoubtResultScreen), findsOneWidget);
  });
  testWidgets('Back from result never starts a second submission',
      (tester) async {
    final api = FakeDoubtApi();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => DoubtProcessingScreen(
                            request: input(), createApi: () => api))),
                child: const Text('Start')))));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    api.pending.complete(SenseiDoubtResponse.fromJson(reply()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byType(DoubtProcessingScreen), findsNothing);
  });
  testWidgets(
      'Try another clears selector and resets the existing shell to Doubt',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const MainLayout()));
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    final source = tester.element(find.byType(SenseiLandingScreen));
    // Exercise the real shared flow callback, without making a network call.
    final flow =
        SenseiImageFlow.selectArea(source, input().imageSelection.image);
    await waitForImage(tester);
    final selector =
        tester.widget<SelectAreaScreen>(find.byType(SelectAreaScreen));
    final processing = selector.onGetHelp!(input());
    await tester.pumpAndSettle();
    final screen = tester
        .widget<DoubtProcessingScreen>(find.byType(DoubtProcessingScreen));
    final navigator =
        Navigator.of(tester.element(find.byType(DoubtProcessingScreen)));
    navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => DoubtResultScreen(
            response: const ResultFixture(),
            request: input(),
            onTryAnother: screen.onTryAnother!)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try another doubt'));
    await tester.pumpAndSettle();
    await processing;
    await flow;
    expect(find.byType(MainLayout), findsOneWidget);
    expect(find.byType(SelectAreaScreen), findsNothing);
    expect(
        tester
            .widget<SenseiBottomNavigation>(find.byType(SenseiBottomNavigation))
            .currentIndex,
        0);
    expect(tester.widget<SenseiModeSwitch>(find.byType(SenseiModeSwitch)).value,
        SenseiMode.doubt);
  });
}
