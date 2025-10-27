import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/gemini_config.dart';
import '../services/voice_agent_audio_pipeline.dart';
import '../services/voice_agent_controller.dart';
import '../widgets/voice_agent_pulse_button.dart';

class VoiceAgentScreen extends StatelessWidget {
  const VoiceAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceAgentController(
        audioPipeline: FlutterSoundVoiceAgentPipeline(),
      ),
      child: const _VoiceAgentView(),
    );
  }
}

class _VoiceAgentView extends StatelessWidget {
  const _VoiceAgentView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VoiceAgentController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensei Voice Agent'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              'Tap the mic to let Sensei listen to your doubt.\n'
              'We will guide you with a spoken explanation.',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            VoiceAgentPulseButton(
              isActive: controller.showWaveAnimation,
              onPressed: controller.isBusy ? () {} : controller.startSession,
            ),
            const SizedBox(height: 32),
            _StatusBadge(status: controller.status),
            const SizedBox(height: 16),
            if (controller.latestTranscript != null)
              _TranscriptCard(transcript: controller.latestTranscript!),
            if (controller.errorDescription != null)
              _ErrorNotice(message: controller.errorDescription!),
            const Spacer(),
            if (!GeminiConfig.isConfigured) const _MissingKeyNotice(),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VoiceAgentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      VoiceAgentStatus.idle => ('Idle', Colors.grey),
      VoiceAgentStatus.preparing => ('Preparing session…', theme.primaryColor),
      VoiceAgentStatus.listening => ('Listening…', theme.primaryColor),
      VoiceAgentStatus.speaking => ('Explaining…', theme.colorScheme.secondary),
      VoiceAgentStatus.completed => ('Done', Colors.green),
      VoiceAgentStatus.missingApiKey => ('Missing API key', Colors.red),
      VoiceAgentStatus.audioUnavailable => (
          'Audio pipeline missing',
          Colors.deepOrange
        ),
      VoiceAgentStatus.error => ('Session failed', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(color: color),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest reply',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              transcript,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MissingKeyNotice extends StatelessWidget {
  const _MissingKeyNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 32),
        Text(
          'Set your Gemini API key in '
          '`lib/features/voice_agent/config/gemini_config.dart`.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
