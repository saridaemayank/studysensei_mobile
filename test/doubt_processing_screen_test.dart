import 'package:study_sensei/features/sensei/screens/doubt_result_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_request.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_mode.dart';
import 'package:study_sensei/features/sensei/models/sensei_doubt_response.dart';
import 'package:study_sensei/features/sensei/models/sensei_doubt_error.dart';
import 'package:study_sensei/features/sensei/services/sensei_doubt_api_service.dart';
import 'package:study_sensei/features/sensei/screens/doubt_processing_screen.dart';
import 'sensei_doubt_api_test.dart' show input, reply;

class FakeDoubtApi implements DoubtApi {
  final pending = Completer<SenseiDoubtResponse>();
  int calls = 0;
  bool closed = false;
  SenseiHelpRequest? request;
  @override
  Future<SenseiDoubtResponse> submit(SenseiHelpRequest value) {
    calls++;
    request = value;
    return pending.future;
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  for (final mode in SenseiHelpMode.values) {
    testWidgets('${mode.name} submits once and immediately hands off result',
        (tester) async {
      final api = FakeDoubtApi();
      final request = input(mode: mode);
      Widget app() => MaterialApp(
          theme: AppTheme.darkTheme,
          home: DoubtProcessingScreen(request: request, createApi: () => api));
      await tester.pumpWidget(app());
      await tester.pumpWidget(app());
      expect(api.calls, 1);
      expect(api.request, same(request));
      final result = SenseiDoubtResponse.fromJson(reply(mode));
      api.pending.complete(result);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DoubtResultScreen>(find.byType(DoubtResultScreen))
              .response,
          same(result));
      expect(api.closed, isTrue);
    });
  }
  testWidgets('Retry spam starts only one fresh request', (tester) async {
    final first = FakeDoubtApi(), second = FakeDoubtApi();
    int created = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: DoubtProcessingScreen(
            request: input(),
            createApi: () => created++ == 0 ? first : second)));
    first.pending
        .completeError(const SenseiDoubtError(DoubtErrorCode.aiTimeout));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensei took too long'), findsOneWidget);
    final button = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Retry'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(created, 2);
    expect(second.calls, 1);
    expect(first.closed, isTrue);
    await tester.pumpWidget(const SizedBox());
    second.pending.complete(SenseiDoubtResponse.fromJson(reply()));
    await tester.pump();
    expect(second.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('Loading and error fit $size with safe areas and large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);
      final api = FakeDoubtApi();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: DoubtProcessingScreen(request: input(), createApi: () => api)));
      expect(tester.takeException(), isNull);
      api.pending.completeError(
          const SenseiDoubtError(DoubtErrorCode.imageUnreadable));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry'));
      expect(tester.takeException(), isNull);
      expect(find.text('Back'), findsOneWidget);
    });
  }
}
