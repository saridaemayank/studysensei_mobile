import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:voxia/voxia.dart';

import '../config/gemini_config.dart';
import 'voice_agent_audio_pipeline.dart';

/// Stages the voice agent moves through during a session.
enum VoiceAgentStatus {
  idle,
  preparing,
  listening,
  speaking,
  completed,
  missingApiKey,
  audioUnavailable,
  error,
}

class VoiceAgentController extends ChangeNotifier {
  VoiceAgentController({
    required VoiceAgentAudioPipeline audioPipeline,
    DateTime Function()? now,
  })  : _audioPipeline = audioPipeline,
        _now = now ?? DateTime.now;

  final VoiceAgentAudioPipeline _audioPipeline;
  final DateTime Function() _now;

  GeminiLiveVoiceInteractor? _voiceInteractor;
  GeminiLiveClient? _client;
  StreamSubscription<GeminiLiveEvent>? _sessionEvents;

  VoiceAgentStatus _status = VoiceAgentStatus.idle;
  VoiceAgentStatus get status => _status;

  bool get isBusy =>
      _status == VoiceAgentStatus.preparing ||
      _status == VoiceAgentStatus.listening ||
      _status == VoiceAgentStatus.speaking;

  bool get showWaveAnimation =>
      _status == VoiceAgentStatus.listening ||
      _status == VoiceAgentStatus.speaking;

  String? _latestTranscript;
  String? get latestTranscript => _latestTranscript;

  String? _errorDescription;
  String? get errorDescription => _errorDescription;

  Future<void> startSession() async {
    if (isBusy) return;

    if (!GeminiConfig.isConfigured) {
      _setStatus(VoiceAgentStatus.missingApiKey);
      _errorDescription =
          'Gemini API key is missing. Paste it into GeminiConfig.geminiLiveApiKey.';
      notifyListeners();
      return;
    }

    try {
      await _audioPipeline.ensureReady();
    } catch (error, stackTrace) {
      _errorDescription = error.toString();
      debugPrint('VoiceAgentController ensureReady error: $error\n$stackTrace');
      _setStatus(VoiceAgentStatus.audioUnavailable);
      notifyListeners();
      return;
    }

    if (!_audioPipeline.isReady) {
      _setStatus(VoiceAgentStatus.audioUnavailable);
      _errorDescription =
          'Audio pipeline is not ready. Check microphone permission and initialisation.';
      notifyListeners();
      return;
    }

    _setStatus(VoiceAgentStatus.preparing);
    _errorDescription = null;

    try {
      _client =
          GeminiLiveWebSocketClient(apiKey: GeminiConfig.geminiLiveApiKey);
      _voiceInteractor = GeminiLiveVoiceInteractor(
        client: _client!,
        audioStreamFactory: (question) async {
          _setStatus(VoiceAgentStatus.listening);
          return _audioPipeline.createInputStream(question);
        },
        audioOutputHandler: (audioBytes) async {
          _setStatus(VoiceAgentStatus.speaking);
          await _audioPipeline.handleOutput(audioBytes);
        },
        now: _now,
      );

      final orchestrator = QuestionnaireOrchestrator(
        voiceInteractor: _voiceInteractor!,
        repository: SharedPreferencesResponseRepository(),
        now: _now,
      );

      _sessionEvents = _client!.events.listen((event) {
        if (event is GeminiLiveErrorEvent) {
          _errorDescription = event.error.toString();
          _setStatus(VoiceAgentStatus.error);
        }
      });

      final questionnaire = Questionnaire(
        id: 'sensei-doubt-helper',
        title: 'Sensei Doubt Helper',
        questions: const [
          Question(
            id: 'describe-doubt',
            prompt:
                'Can you describe the doubt you would like me to help with?',
            hint: 'Share any context or topic so I can guide you better.',
          ),
        ],
      );

      final result = await orchestrator.run(
        questionnaire: questionnaire,
        systemPrompt:
            'You are Study Sensei, a friendly tutor who answers questions concisely.',
      );

      result.when(
        success: (sessionResult) {
          if (sessionResult.responses.isNotEmpty) {
            _latestTranscript = sessionResult.responses.last.response;
          }
          _setStatus(VoiceAgentStatus.completed);
        },
        failure: (error, stackTrace) {
          _errorDescription = error.toString();
          _setStatus(VoiceAgentStatus.error);
        },
      );
    } catch (error, stackTrace) {
      _errorDescription = '$error';
      debugPrint(
          'VoiceAgentController startSession error: $error\n$stackTrace');
      _setStatus(VoiceAgentStatus.error);
    } finally {
      await _teardownSession();
      await _audioPipeline.reset();
    }
  }

  void reset() {
    if (isBusy) return;

    _latestTranscript = null;
    _errorDescription = null;
    _setStatus(VoiceAgentStatus.idle);
    unawaited(_audioPipeline.reset());
  }

  Future<void> _teardownSession() async {
    await _sessionEvents?.cancel();
    _sessionEvents = null;
    _voiceInteractor = null;
    _client = null;
  }

  void _setStatus(VoiceAgentStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionEvents?.cancel();
    unawaited(_audioPipeline.dispose());
    super.dispose();
  }
}
