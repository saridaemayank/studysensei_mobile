import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:study_sensei/features/sensei/models/academic_level.dart';
import 'package:study_sensei/features/sensei/models/focus_region.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_mode.dart';
import 'package:study_sensei/features/sensei/models/sensei_help_request.dart';
import 'package:study_sensei/features/sensei/models/sensei_image_selection.dart';
import 'package:study_sensei/features/sensei/models/sensei_doubt_error.dart';
import 'package:study_sensei/features/sensei/models/sensei_doubt_response.dart';
import 'package:study_sensei/features/sensei/services/sensei_doubt_api_service.dart';

Map<String, Object?> reply([SenseiHelpMode mode = SenseiHelpMode.explain]) => {
      'version': 1,
      'mode': mode.apiValue,
      'subject': 'Mathematics',
      'topic': 'Algebra',
      'title': 'Distribute the factor',
      'explanation': 'Multiply each term.',
      'confidence': .9,
      'inputStatus': 'readable',
      'concept': mode == SenseiHelpMode.explain ? 'Distribution' : null,
      'keyIdea':
          mode == SenseiHelpMode.explain ? 'Each term is multiplied.' : null,
      'nextAction': 'Try the next line.',
      'workStatus': mode == SenseiHelpMode.checkWork ? 'correct' : null,
      'mistake': null,
      'mistakeType': mode == SenseiHelpMode.checkWork ? 'none' : null,
      'correctedStep': null,
      'hint': mode == SenseiHelpMode.hint ? 'Look at the factor.' : null,
      'hintLevel': mode == SenseiHelpMode.hint ? 1 : null,
    };
SenseiHelpRequest input(
        {SenseiHelpMode mode = SenseiHelpMode.explain, String? prompt}) =>
    SenseiHelpRequest(
        imageSelection: SenseiImageSelection(
            image: XFile.fromData(
                File('test/fixtures/portrait.png').readAsBytesSync(),
                name: 'test.png'),
            focusRegion:
                const FocusRegion(x: .1, y: .2, width: .3, height: .4)),
        mode: mode,
        academicLevel: AcademicLevel.boards,
        userPrompt: prompt);

class TestHttp extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handle;
  int calls = 0;
  bool closed = false;
  TestHttp(this.handle);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    return handle(request);
  }

  @override
  void close() {
    closed = true;
  }
}

http.StreamedResponse response(Object body, [int status = 200]) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status);
Matcher errorCode(DoubtErrorCode code) =>
    isA<SenseiDoubtError>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Wire mappings and normalized coordinates', () {
    expect(SenseiHelpMode.values.map((m) => m.apiValue),
        ['explain', 'check_work', 'hint']);
    expect(AcademicLevel.values.map((m) => m.apiValue),
        ['school', 'boards', 'jee']);
    expect(input().imageSelection.focusRegion.toJson(),
        {'x': .1, 'y': .2, 'width': .3, 'height': .4});
  });
  for (final mode in SenseiHelpMode.values) {
    test('Authenticated multipart and parsed ${mode.name} handoff', () async {
      final request = input(mode: mode, prompt: 'What changed here?');
      final client = TestHttp((raw) async {
        final multipart = raw as http.MultipartRequest;
        expect(multipart.url, SenseiDoubtApiService.endpoint);
        expect(multipart.headers['Authorization'], 'Bearer test-token');
        expect(multipart.fields, {
          'focusRegion':
              jsonEncode(request.imageSelection.focusRegion.toJson()),
          'helpMode': mode.apiValue,
          'academicLevel': 'boards',
          'userPrompt': 'What changed here?',
        });
        expect(multipart.fields.containsKey('uid'), isFalse);
        expect(multipart.files.single.field, 'image');
        expect(multipart.files.single.contentType.toString(), 'image/png');
        expect(await multipart.files.single.finalize().toBytes(),
            await request.imageSelection.image.readAsBytes());
        return response(reply(mode));
      });
      final api = SenseiDoubtApiService(
          client: client, token: () async => 'test-token');
      final result = await api.submit(request);
      expect(result.version, 1);
      expect(result.mode, mode);
      expect(result.confidence, .9);
      expect(client.calls, 1);
      api.close();
    });
  }
  test('Optional prompt omitted and token acquired per submission', () async {
    int tokens = 0;
    final client = TestHttp((raw) async {
      expect((raw as http.MultipartRequest).fields.containsKey('userPrompt'),
          isFalse);
      return response(reply());
    });
    final api = SenseiDoubtApiService(
        client: client,
        token: () async {
          tokens++;
          return 'token';
        });
    await api.submit(input());
    await api.submit(input());
    expect(tokens, 2);
    api.close();
  });
  test('Unauthenticated request never sends HTTP', () async {
    final client = TestHttp((_) async => response(reply()));
    final api = SenseiDoubtApiService(client: client, token: () async => null);
    await expectLater(
        api.submit(input()), throwsA(errorCode(DoubtErrorCode.unauthorized)));
    expect(client.calls, 0);
    api.close();
  });
  test('Oversized prompt rejected before send', () async {
    final client = TestHttp((_) async => response(reply()));
    final api =
        SenseiDoubtApiService(client: client, token: () async => 'token');
    await expectLater(api.submit(input(prompt: 'a' * 2001)),
        throwsA(errorCode(DoubtErrorCode.invalidRequest)));
    expect(client.calls, 0);
    api.close();
  });
  test('Malformed response and unsupported version are typed', () {
    for (final bad in [
      null,
      [],
      {},
      {...reply(), 'confidence': 2},
      {...reply(), 'inputStatus': 'bad'},
      {...reply(), 'title': null}
    ]) {
      expect(() => SenseiDoubtResponse.fromJson(bad),
          throwsA(errorCode(DoubtErrorCode.malformedResponse)));
    }
    expect(() => SenseiDoubtResponse.fromJson({...reply(), 'version': 2}),
        throwsA(errorCode(DoubtErrorCode.unsupportedVersion)));
  });
  for (final code in [
    'INVALID_REQUEST',
    'UNAUTHORIZED',
    'IMAGE_UNREADABLE',
    'MEDIA_PROCESSING_FAILED',
    'AI_TIMEOUT',
    'AI_RESPONSE_INVALID',
    'INTERNAL_ERROR'
  ]) {
    test('Backend $code maps without exposing server content', () async {
      final client = TestHttp((_) async => response({
            'error': {'code': code, 'message': 'private server content'}
          }, 400));
      final api =
          SenseiDoubtApiService(client: client, token: () async => 'token');
      await expectLater(api.submit(input()),
          throwsA(errorCode(DoubtErrorCode.fromBackend(code))));
      expect(client.calls, 1);
      api.close();
    });
  }
  test('Network failure maps to typed error', () async {
    final api = SenseiDoubtApiService(
        client: TestHttp((_) async => throw http.ClientException('private')),
        token: () async => 'token');
    await expectLater(
        api.submit(input()), throwsA(errorCode(DoubtErrorCode.network)));
    api.close();
  });
  test('Timeout closes transport; no automatic retry', () async {
    final client = TestHttp((_) => Completer<http.StreamedResponse>().future);
    final api = SenseiDoubtApiService(
        client: client,
        token: () async => 'token',
        timeout: const Duration(milliseconds: 100));
    await expectLater(
        api.submit(input()), throwsA(errorCode(DoubtErrorCode.timeout)));
    expect(client.calls, 1);
    expect(client.closed, isTrue);
  });
  test('Closed and concurrent requests cannot send extra HTTP calls', () async {
    final pending = Completer<http.StreamedResponse>();
    final started = Completer<void>();
    final client = TestHttp((_) {
      started.complete();
      return pending.future;
    });
    final api =
        SenseiDoubtApiService(client: client, token: () async => 'token');
    final first = api.submit(input());
    await started.future;
    await expectLater(
        api.submit(input()), throwsA(errorCode(DoubtErrorCode.invalidRequest)));
    api.close();
    pending.complete(response(reply()));
    await expectLater(first, throwsA(errorCode(DoubtErrorCode.cancelled)));
    await expectLater(
        api.submit(input()), throwsA(errorCode(DoubtErrorCode.cancelled)));
    expect(client.calls, 1);
  });
  test('Contradictory mode-specific fields are rejected', () {
    expect(
        () => SenseiDoubtResponse.fromJson({
              ...reply(SenseiHelpMode.checkWork),
              'mistake': 'Contradicts correct status'
            }),
        throwsA(errorCode(DoubtErrorCode.malformedResponse)));
    expect(
        () => SenseiDoubtResponse.fromJson(
            {...reply(SenseiHelpMode.hint), 'hintLevel': null}),
        throwsA(errorCode(DoubtErrorCode.malformedResponse)));
    expect(() => SenseiDoubtResponse.fromJson({...reply(), 'concept': null}),
        throwsA(errorCode(DoubtErrorCode.malformedResponse)));
  });
  test('Malformed JSON and mismatched mode are rejected', () async {
    for (final body in ['not-json', jsonEncode(reply(SenseiHelpMode.hint))]) {
      final api = SenseiDoubtApiService(
          client: TestHttp((_) async =>
              http.StreamedResponse(Stream.value(utf8.encode(body)), 200)),
          token: () async => 'token');
      await expectLater(api.submit(input()),
          throwsA(errorCode(DoubtErrorCode.malformedResponse)));
      api.close();
    }
  });
}
