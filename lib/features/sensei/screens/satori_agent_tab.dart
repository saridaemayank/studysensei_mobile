import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/livekit_credentials.dart';
import '../services/backend_service.dart';

class SatoriAgentTab extends StatefulWidget {
  final BackendService backendService;
  final String subject;
  final String concept;
  final bool isProUser;

  const SatoriAgentTab({
    super.key,
    required this.backendService,
    required this.subject,
    required this.concept,
    this.isProUser = false,
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
  static const Duration _freeWeeklyAllowance = Duration(minutes: 5);
  static const Duration _proWeeklyAllowance = Duration(minutes: 15);
  static const Color _idleAccent = Color(0xFF7B3FF3);

  late lk.Room _room;
  lk.EventsListener<lk.RoomEvent>? _roomEvents;
  late final AnimationController _pulseController;
  SharedPreferences? _prefs;

  lk.RemoteParticipant? _agentParticipant;
  _ConnectionStatus _status = _ConnectionStatus.idle;
  String _agentState = 'offline';
  String? _errorMessage;
  bool _micEnabled = true;

  Timer? _sessionTimer;
  Duration? _remainingDuration;
  bool _timerInitialized = false;
  DateTime? _currentWeekStartUtc;
  bool _isResettingRoom = false;

  Duration get _weeklyAllowance =>
      widget.isProUser ? _proWeeklyAllowance : _freeWeeklyAllowance;

  String? get _userId => widget.backendService.user?.uid;
  String _weekKey(String uid) => 'satori_week_start_$uid';
  String _remainingKey(String uid) => 'satori_week_seconds_$uid';
  String _planKey(String uid) => 'satori_week_plan_$uid';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _room = _createRoom();
    _attachRoomEvents();
    Future.microtask(_initializeTimerState);
    _refreshPulseAnimation();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _roomEvents?.dispose();
    _pulseController.dispose();
    unawaited(_room.dispose());
    super.dispose();
  }

  Future<void> _connectToAgent() async {
    await _waitForRoomReady();
    if (_status == _ConnectionStatus.fetchingCredentials ||
        _status == _ConnectionStatus.connecting ||
        _status == _ConnectionStatus.connected) {
      return;
    }

    await _initializeTimerState(forceReload: true);
    _remainingDuration ??= _weeklyAllowance;
    if ((_remainingDuration?.inSeconds ?? 0) <= 0) {
      _updateStatus(
        _ConnectionStatus.error,
        message: widget.isProUser
            ? 'You have used your weekly Satori time allocation.'
            : 'You have used all of your free Satori time for this week.',
      );
      await _showUsageLimitDialog(isProUser: widget.isProUser);
      return;
    }

    _updateStatus(_ConnectionStatus.fetchingCredentials);

    try {
      final roomName =
          'satori-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(1 << 20)}';

      final LiveKitCredentials credentials =
          await widget.backendService.createSatoriSession(
        subject: widget.subject,
        concept: widget.concept,
        roomName: roomName,
      );

      _updateStatus(_ConnectionStatus.connecting);

      await _room.connect(
        credentials.url,
        credentials.token,
      );

      await _room.localParticipant?.setMicrophoneEnabled(true);
      await _room.localParticipant?.setCameraEnabled(false);

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
    }
  }

  Future<void> _disconnect() async {
    if (_status != _ConnectionStatus.connected) return;

    _updateStatus(_ConnectionStatus.disconnecting);

    try {
      await _room.disconnect();
      await _resetRoom();
    } finally {
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
      return;
    }

    if (event is lk.ParticipantDisconnectedEvent &&
        event.participant == _agentParticipant) {
      setState(() {
        _agentParticipant = null;
        _agentState = 'offline';
      });
      _updateStatus(_ConnectionStatus.idle);
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
    if (newStatus == _ConnectionStatus.connected) {
      _startSessionTimer();
    } else {
      _sessionTimer?.cancel();
    }
    if (_timerInitialized && _remainingDuration != null) {
      unawaited(_persistWeeklyUsage(_remainingDuration!));
    }
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

  void _startSessionTimer() {
    if (!_timerInitialized) return;

    _sessionTimer?.cancel();
    _remainingDuration ??= _weeklyAllowance;

    if (_remainingDuration!.inSeconds <= 0) {
      unawaited(_persistWeeklyUsage(Duration.zero));
      _handleSessionExpired();
      return;
    }

    unawaited(_persistWeeklyUsage(_remainingDuration!));

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingDuration == null) {
        timer.cancel();
        return;
      }
      if (_remainingDuration!.inSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingDuration = Duration.zero);
        unawaited(_persistWeeklyUsage(Duration.zero));
        _handleSessionExpired();
      } else {
        setState(
          () => _remainingDuration =
              _remainingDuration! - const Duration(seconds: 1),
        );
        unawaited(_persistWeeklyUsage(_remainingDuration!));
      }
    });
  }

  Future<void> _handleSessionExpired() async {
    await _disconnect();
    if (!mounted) return;
    await _showUsageLimitDialog(isProUser: widget.isProUser);
  }

  Future<void> _initializeTimerState({bool forceReload = false}) async {
    if (_timerInitialized && !forceReload) {
      return;
    }

    final uid = _userId;
    if (uid == null) {
      setState(() {
        _remainingDuration = _weeklyAllowance;
        _timerInitialized = true;
      });
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    final nowUtc = DateTime.now().toUtc();
    final weekStart = _weekStart(nowUtc);
    _currentWeekStartUtc = weekStart;

    final storedWeekMs = _prefs!.getInt(_weekKey(uid));

    final storedRemaining = _prefs!.getInt(_remainingKey(uid));
    final storedPlan = _prefs!.getString(_planKey(uid));
    final currentPlan = widget.isProUser ? 'premium' : 'free';
    final freeAllowanceSeconds = _freeWeeklyAllowance.inSeconds;
    final premiumAllowanceSeconds = _proWeeklyAllowance.inSeconds;

    if (storedWeekMs == null ||
        storedRemaining == null ||
        storedWeekMs < weekStart.millisecondsSinceEpoch) {
      _remainingDuration = _weeklyAllowance;
      await _persistWeeklyUsage(_remainingDuration!);
      await _prefs!.setString(_planKey(uid), currentPlan);
    } else {
      var effectiveSeconds = storedRemaining < 0 ? 0 : storedRemaining;
      final previousSeconds = effectiveSeconds;
      final planChanged = storedPlan != null && storedPlan != currentPlan;

      if (planChanged) {
        if (currentPlan == 'premium' && storedPlan == 'free') {
          final usedSeconds = _clampInt(
            freeAllowanceSeconds - effectiveSeconds,
            0,
            freeAllowanceSeconds,
          );
          effectiveSeconds = _clampInt(
            premiumAllowanceSeconds - usedSeconds,
            0,
            premiumAllowanceSeconds,
          );
        } else if (currentPlan == 'free' && storedPlan == 'premium') {
          effectiveSeconds =
              _clampInt(effectiveSeconds, 0, freeAllowanceSeconds);
        }
      }

      if (widget.isProUser) {
        effectiveSeconds =
            _clampInt(effectiveSeconds, 0, premiumAllowanceSeconds);
      } else {
        effectiveSeconds = _clampInt(effectiveSeconds, 0, freeAllowanceSeconds);
      }

      if (effectiveSeconds != previousSeconds || planChanged) {
        await _persistWeeklyUsage(Duration(seconds: effectiveSeconds));
      }

      _remainingDuration = Duration(seconds: effectiveSeconds);
      if (planChanged || storedPlan == null) {
        await _prefs!.setString(_planKey(uid), currentPlan);
      }
    }

    setState(() {
      _timerInitialized = true;
    });
  }

  Future<void> _persistWeeklyUsage(Duration remaining) async {
    final uid = _userId;
    if (uid == null) return;

    _prefs ??= await SharedPreferences.getInstance();
    final weekStart =
        _currentWeekStartUtc ?? _weekStart(DateTime.now().toUtc());
    _currentWeekStartUtc = weekStart;

    final cappedSeconds = math.max(
      0,
      math.min(
        remaining.inSeconds,
        _weeklyAllowance.inSeconds,
      ),
    );

    await _prefs!.setInt(
      _weekKey(uid),
      weekStart.millisecondsSinceEpoch,
    );
    await _prefs!.setInt(
      _remainingKey(uid),
      cappedSeconds,
    );
    await _prefs!.setString(
      _planKey(uid),
      widget.isProUser ? 'premium' : 'free',
    );
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  DateTime _weekStart(DateTime utcNow) {
    final midnight = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final daysFromMonday = (midnight.weekday - DateTime.monday) % 7;
    return midnight.subtract(Duration(days: daysFromMonday));
  }

  Future<void> _showUsageLimitDialog({required bool isProUser}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly limit reached'),
        content: Text(
          isProUser
              ? 'You have reached your 15-minute weekly Satori allowance. It resets every Monday.'
              : 'You have used all of your free Satori time for this week. Upgrade to Study Sensei Pro to unlock 15 minutes weekly.',
        ),
        actions: isProUser
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Okay'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Maybe later'),
                ),
                FilledButton(
                  onPressed: () {
                    final navigator =
                        Navigator.of(context, rootNavigator: true);
                    navigator.pop();
                    navigator.pushNamed('/profile');
                  },
                  child: const Text('Explore Pro'),
                ),
              ],
      ),
    );
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
    final timerDuration = _timerInitialized ? _remainingDuration : null;

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
                const SizedBox(height: 24),
                _TimerBadge(
                  isPro: widget.isProUser,
                  duration: timerDuration,
                  defaultDuration: _weeklyAllowance,
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

class _TimerBadge extends StatelessWidget {
  final bool isPro;
  final Duration? duration;
  final Duration? defaultDuration;

  const _TimerBadge({
    required this.isPro,
    required this.duration,
    required this.defaultDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayDuration = duration ?? defaultDuration;

    final label = displayDuration == null
        ? 'Calculating…'
        : '${isPro ? 'Premium' : 'Free'} · ${_formatDuration(displayDuration)} left this week';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
