import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../models/livekit_credentials.dart';
import '../services/backend_service.dart';

class SatoriAgentTab extends StatefulWidget {
  final BackendService backendService;
  final String subject;
  final String concept;

  const SatoriAgentTab({
    super.key,
    required this.backendService,
    required this.subject,
    required this.concept,
  });

  @override
  State<SatoriAgentTab> createState() => _SatoriAgentTabState();
}

enum _ConnectionStatus {
  idle,
  fetchingCredentials,
  connecting,
  connected,
  disconnecting,
  error,
}

class _SatoriAgentTabState extends State<SatoriAgentTab>
    with SingleTickerProviderStateMixin {
  static const Color _idleAccent = Color(0xFF7B3FF3);

  late lk.Room _room;
  lk.EventsListener<lk.RoomEvent>? _roomEvents;
  late final AnimationController _pulseController;

  lk.RemoteParticipant? _agentParticipant;
  LiveKitCredentials? _activeCredentials;
  _ConnectionStatus _status = _ConnectionStatus.idle;
  String _agentState = 'offline';
  String? _errorMessage;
  bool _micEnabled = true;

  bool _isResettingRoom = false;
  bool _kickoffSent = false;
  bool _audioPlaybackStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _room = _createRoom();
    _attachRoomEvents();
    _refreshPulseAnimation();
  }

  @override
  void dispose() {
    _roomEvents?.dispose();
    _pulseController.dispose();
    unawaited(_room.dispose());
    unawaited(_cancelActiveDispatch(fireAndForget: true));
    _kickoffSent = false;
    super.dispose();
  }

  Future<void> _connectToAgent() async {
    final hasMicPermission = await _ensureMicrophonePermission();
    if (!hasMicPermission) {
      _updateStatus(
        _ConnectionStatus.error,
        message: 'Microphone access is required to talk to Satori.',
      );
      return;
    }

    await _waitForRoomReady();
    if (_status == _ConnectionStatus.fetchingCredentials ||
        _status == _ConnectionStatus.connecting ||
        _status == _ConnectionStatus.connected) {
      return;
    }

    _updateStatus(_ConnectionStatus.fetchingCredentials);
    _kickoffSent = false;

    try {
      final roomName =
          'satori-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(1 << 20)}';

      final LiveKitCredentials credentials =
          await widget.backendService.createSatoriSession(
        subject: widget.subject,
        concept: widget.concept,
        roomName: roomName,
      );

      if (!mounted) {
        unawaited(widget.backendService.cancelSatoriDispatch(credentials));
        return;
      }

      setState(() {
        _activeCredentials = credentials;
      });

      _updateStatus(_ConnectionStatus.connecting);

      await _room.connect(
        credentials.url,
        credentials.token,
      );

      await _room.localParticipant?.setMicrophoneEnabled(true);
      await _room.localParticipant?.setCameraEnabled(false);
      await _ensureAudioPlayback();

      if (!mounted) return;
      setState(() {
        _agentState = '';
        _micEnabled = true;
      });

      _updateStatus(_ConnectionStatus.connected);
    } catch (e) {
      _updateStatus(
        _ConnectionStatus.error,
        message: e.toString(),
      );
      await _cancelActiveDispatch(fireAndForget: true);
    }
  }

  Future<void> _disconnect() async {
    if (_status != _ConnectionStatus.connected) return;

    _updateStatus(_ConnectionStatus.disconnecting);

    try {
      await _room.disconnect();
      await _resetRoom();
    } finally {
      await _cancelActiveDispatch();
      if (mounted) {
        setState(() {
          _agentParticipant = null;
          _agentState = 'offline';
          _micEnabled = true;
        });
      }
      _updateStatus(_ConnectionStatus.idle);
    }
  }

  Future<void> _toggleMic() async {
    final localParticipant = _room.localParticipant;
    if (localParticipant == null ||
        _status != _ConnectionStatus.connected ||
        _room.connectionState != lk.ConnectionState.connected) {
      return;
    }

    final nextValue = !_micEnabled;
    try {
      await localParticipant.setMicrophoneEnabled(nextValue);
      if (!mounted) return;
      setState(() => _micEnabled = nextValue);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Unable to toggle microphone: $e')),
      );
    }
  }

  void _handleRoomEvent(lk.RoomEvent event) {
    if (!mounted) return;

    if (event is lk.RoomDisconnectedEvent) {
      setState(() {
        _agentParticipant = null;
        _agentState = 'offline';
      });
      unawaited(_resetRoom());
      unawaited(_cancelActiveDispatch());
      _updateStatus(_ConnectionStatus.idle);
      return;
    }

    if (event is lk.ParticipantConnectedEvent &&
        event.participant.kind == lk.ParticipantKind.AGENT) {
      setState(() {
        _agentParticipant = event.participant;
        _agentState =
            event.participant.attributes['lk.agent.state'] ?? 'listening';
      });
      unawaited(_sendKickoffPrompt(event.participant));
      return;
    }

    if (event is lk.ParticipantDisconnectedEvent &&
        event.participant == _agentParticipant) {
      setState(() {
        _agentParticipant = null;
        _agentState = 'offline';
      });
      unawaited(_cancelActiveDispatch());
      _updateStatus(_ConnectionStatus.idle);
      _kickoffSent = false;
      return;
    }

    if (event is lk.ParticipantAttributesChanged &&
        event.participant == _agentParticipant) {
      setState(() {
        _agentState =
            event.participant.attributes['lk.agent.state'] ?? _agentState;
      });
    }
  }

  void _updateStatus(
    _ConnectionStatus newStatus, {
    String? message,
  }) {
    if (!mounted) return;
    setState(() {
      _status = newStatus;
      if (message != null) {
        _errorMessage = message;
      } else if (newStatus != _ConnectionStatus.error) {
        _errorMessage = null;
      }
      if (newStatus != _ConnectionStatus.connected) {
        _micEnabled = true;
      }
    });
    _refreshPulseAnimation();
  }

  void _refreshPulseAnimation() {
    final shouldAnimate = switch (_status) {
      _ConnectionStatus.fetchingCredentials => true,
      _ConnectionStatus.connecting => true,
      _ConnectionStatus.connected => true,
      _ConnectionStatus.disconnecting => true,
      _ => false,
    };

    if (shouldAnimate) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 0;
    }
  }

  Future<void> _cancelActiveDispatch({bool fireAndForget = false}) async {
    final credentials = _activeCredentials;
    if (credentials == null) return;
    _activeCredentials = null;

    Future<void> cancel() =>
        widget.backendService.cancelSatoriDispatch(credentials);

    if (fireAndForget) {
      unawaited(cancel());
    } else {
      await cancel();
    }
  }

  Future<void> _ensureAudioPlayback() async {
    if (_audioPlaybackStarted) return;
    try {
      await _room.startAudio();
      await _room.setSpeakerOn(true);
      _audioPlaybackStarted = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Unable to start audio playback: $e')),
      );
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (!mounted) return false;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (result.isPermanentlyDenied) {
      messenger?.showSnackBar(
        SnackBar(
          content: const Text(
            'Microphone access is blocked. Enable it in system settings to chat with Satori.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    } else {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to talk to Satori.'),
        ),
      );
    }
    return false;
  }

  Future<void> _sendKickoffPrompt(lk.RemoteParticipant participant) async {
    if (_kickoffSent) return;
    final localParticipant = _room.localParticipant;
    if (localParticipant == null) return;

    final payload = jsonEncode({
      'type': 'instruction',
      'variant': 'kickoff',
      'message':
          'You are Satori, a friendly doubt-solving tutor. Begin the session '
              'without waiting for the student. Introduce yourself and invite '
              'them to discuss ${widget.concept} in ${widget.subject}. Keep it concise.',
    });

    try {
      await localParticipant.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'sensei.kickoff',
        destinationIdentities: [participant.identity],
      );
      _kickoffSent = true;
    } catch (_) {}
  }

  lk.Room _createRoom() {
    return lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: lk.AudioPublishOptions(
          name: 'student-mic',
          dtx: true,
        ),
      ),
    );
  }

  void _attachRoomEvents() {
    _roomEvents?.dispose();
    _roomEvents = _room.createListener();
    _roomEvents!.listen(_handleRoomEvent);
  }

  Future<void> _resetRoom() async {
    if (_isResettingRoom) return;
    _isResettingRoom = true;
    try {
      _roomEvents?.dispose();
      _roomEvents = null;
      try {
        await _room.dispose();
      } catch (_) {}
      _room = _createRoom();
      _attachRoomEvents();
    } finally {
      _isResettingRoom = false;
    }
  }

  Future<void> _waitForRoomReady() async {
    while (_isResettingRoom) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  Color _indicatorColor(ThemeData theme) {
    return switch (_status) {
      _ConnectionStatus.connected => theme.colorScheme.primary,
      _ConnectionStatus.connecting ||
      _ConnectionStatus.fetchingCredentials =>
        theme.colorScheme.secondary,
      _ConnectionStatus.disconnecting => theme.colorScheme.tertiary,
      _ConnectionStatus.error => theme.colorScheme.error,
      _ConnectionStatus.idle => _idleAccent,
    };
  }

  String get _headline => switch (_status) {
        _ConnectionStatus.idle => 'Connect with Satori',
        _ConnectionStatus.fetchingCredentials => 'Minting token…',
        _ConnectionStatus.connecting => 'Connecting…',
        _ConnectionStatus.connected => 'Disconnect',
        _ConnectionStatus.disconnecting => 'Disconnecting…',
        _ConnectionStatus.error => 'Tap to retry',
      };

  String? _subtext() {
    if (_status == _ConnectionStatus.connected) {
      return _agentState.isEmpty ? 'online' : _agentState;
    }
    if (_status == _ConnectionStatus.error) {
      return (_errorMessage != null && _errorMessage!.isNotEmpty)
          ? _errorMessage
          : 'Unable to reach Satori';
    }
    return null;
  }

  void _onOrbTap() {
    switch (_status) {
      case _ConnectionStatus.idle:
        _connectToAgent();
        break;
      case _ConnectionStatus.connected:
        _disconnect();
        break;
      case _ConnectionStatus.error:
        _connectToAgent();
        break;
      case _ConnectionStatus.fetchingCredentials:
      case _ConnectionStatus.connecting:
      case _ConnectionStatus.disconnecting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = _indicatorColor(theme);
    final isBusy = _status == _ConnectionStatus.fetchingCredentials ||
        _status == _ConnectionStatus.connecting ||
        _status == _ConnectionStatus.disconnecting;
    final isActive =
        _status != _ConnectionStatus.idle && _status != _ConnectionStatus.error;

    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final progress =
              _pulseController.isAnimating ? _pulseController.value : 0.0;
          final wave = (math.sin(progress * 2 * math.pi) + 1) / 2;
          final scale = isActive ? 0.94 + (wave * 0.1) : 0.96;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isBusy ? null : _onOrbTap,
                  child: Transform.scale(
                    scale: scale,
                    child: _PulseOrb(
                      progress: progress,
                      color: indicatorColor,
                      isActive: isActive || isBusy,
                      headline: _headline,
                      subtext: _subtext(),
                      showProgress: isBusy,
                      showError: _status == _ConnectionStatus.error,
                    ),
                  ),
                ),
                if (_status == _ConnectionStatus.error &&
                    (_errorMessage?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ControlIconButton(
                        tooltip: _micEnabled
                            ? 'Mute microphone'
                            : 'Unmute microphone',
                        icon: _micEnabled ? Icons.mic : Icons.mic_off,
                        onPressed: _status == _ConnectionStatus.connected
                            ? _toggleMic
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ControlIconButton(
                        tooltip: 'End session',
                        icon: Icons.call_end,
                        isPrimary: true,
                        onPressed: _status == _ConnectionStatus.connected
                            ? _disconnect
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PulseOrb extends StatelessWidget {
  final double progress;
  final Color color;
  final bool isActive;
  final String headline;
  final String? subtext;
  final bool showProgress;
  final bool showError;

  const _PulseOrb({
    required this.progress,
    required this.color,
    required this.isActive,
    required this.headline,
    required this.subtext,
    required this.showProgress,
    required this.showError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double coreSize = 200.0;
    const double canvasSize = coreSize * 2;
    final highlight = Color.lerp(color, Colors.white, 0.2);

    List<Widget> _buildPulseLayers() {
      if (!isActive) return const [];

      return List.generate(3, (index) {
        final offset = index * 0.28;
        final normalized = (progress + offset) % 1.0;
        final intensity = 1 - normalized;
        final scale = 1.2 + normalized * 1.4;
        final opacity = (intensity.clamp(0.0, 1.0)) * 0.35;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: coreSize,
              height: coreSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.02),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12 * intensity),
                    blurRadius: 44,
                    spreadRadius: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      });
    }

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ..._buildPulseLayers(),
          Container(
            width: coreSize * 1.45,
            height: coreSize * 1.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: isActive ? 0.24 : 0.18),
                  color.withValues(alpha: 0.02),
                ],
                stops: const [0.35, 1],
              ),
            ),
          ),
          Container(
            width: coreSize,
            height: coreSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isActive ? 0.96 : 0.92),
                  (highlight ?? color)
                      .withValues(alpha: isActive ? 0.85 : 0.68),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isActive ? 0.28 : 0.14),
                  blurRadius: isActive ? 34 : 22,
                  spreadRadius: isActive ? 3 : 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 1),
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isActive || showProgress || showError) ...[
                    _PulseDots(progress: progress, isActive: true),
                    const SizedBox(height: 18),
                    if (showProgress)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else if (showError)
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 46,
                      )
                    else
                      const SizedBox(height: 46),
                  ] else ...[
                    Icon(
                      Icons.spatial_audio_off_rounded,
                      color: color,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isActive || showProgress || showError
                          ? Colors.white
                          : color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtext != null && subtext!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtext!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final bool isPrimary;
  final String tooltip;

  const _ControlIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isPrimary
        ? theme.colorScheme.error
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = isPrimary ? Colors.white : theme.colorScheme.onSurface;

    return SizedBox(
      height: 60,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 26,
        style: IconButton.styleFrom(
          backgroundColor: onPressed != null
              ? background
              : background.withValues(alpha: 0.5),
          foregroundColor:
              onPressed != null ? foreground : foreground.withOpacity(0.6),
          minimumSize: const Size(60, 56),
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _PulseDots extends StatelessWidget {
  final double progress;
  final bool isActive;

  const _PulseDots({
    required this.progress,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(5, (index) {
      final phase = (progress * 2 * math.pi) + index * 0.8;
      final scale = isActive ? 0.6 + (math.sin(phase) + 1) * 0.2 : 0.6;
      return Transform.scale(
        scale: scale,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
    });

    return SizedBox(
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < dots.length; i++) ...[
            dots[i],
            if (i != dots.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
