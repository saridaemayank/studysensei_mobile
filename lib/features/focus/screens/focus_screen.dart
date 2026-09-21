import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/focus_notifications.dart';
import '../services/focus_session_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/sensei_primary_button.dart';
import '../controllers/focus_timer_controller.dart';
import '../widgets/flip_clock.dart';
import '../widgets/focus_scene.dart';

enum FocusViewState { setup, entering, running, paused, completed }

/// Lets the shell quiet its existing navigation without owning timer state.
class FocusActivityNotification extends Notification {
  final bool active;
  const FocusActivityNotification(this.active);
}

class FocusScreen extends StatefulWidget {
  final FocusTimerController? controller;
  const FocusScreen({super.key, this.controller});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final FocusTimerController _timer = widget.controller ??
      FocusTimerController(
          storage: PreferencesFocusSessionStorage(),
          notifications: LocalFocusNotifications(),
          onForegroundCompletion: () async {
            try {
              await HapticFeedback.mediumImpact();
            } catch (_) {
              debugPrint('Focus: haptic_unavailable');
            }
          });
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  FocusSessionStatus _status = FocusSessionStatus.setup;
  FocusViewState _view = FocusViewState.setup;
  bool _custom = false;
  bool _restoring = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer.addListener(_changed);
    _entry.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _timer.isRunning) {
        setState(() => _view = FocusViewState.running);
      }
    });
    if (widget.controller == null) {
      _restoring = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _timer.restore();
        if (!mounted) return;
        setState(() {
          _restoring = false;
          _custom = ![25, 45, 60, _timer.sessionType.minutes]
              .contains(_timer.selectedDuration.inMinutes);
          _entry.value = _timer.status == FocusSessionStatus.setup ? 0 : 1;
        });
      });
    }
    _status = _timer.status;
    if (_status != FocusSessionStatus.setup) {
      _entry.value = 1;
      _view = _viewForStatus;
    }
  }

  FocusViewState get _viewForStatus => switch (_timer.status) {
        FocusSessionStatus.setup => FocusViewState.setup,
        FocusSessionStatus.running => FocusViewState.running,
        FocusSessionStatus.paused => FocusViewState.paused,
        FocusSessionStatus.completed => FocusViewState.completed,
      };
  void _changed() {
    if (!mounted) return;
    if (_status == _timer.status) {
      if (_restoring) setState(() {});
      return;
    }
    setState(() {
      _status = _timer.status;
      _view = _viewForStatus;
    });
    FocusActivityNotification(_timer.isRunning || _timer.isPaused)
        .dispatch(context);
    if (_status == FocusSessionStatus.setup) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _entry.value = 0;
      } else {
        _entry.reverse();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer.setForeground(state == AppLifecycleState.resumed);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.removeListener(_changed);
    if (widget.controller == null) _timer.dispose();
    _entry.dispose();
    super.dispose();
  }

  void _start() {
    if (_restoring) return;
    _timer.start();
    setState(() => _view = FocusViewState.entering);
    if (MediaQuery.disableAnimationsOf(context) || _entry.value == 1) {
      _entry.value = 1;
      setState(() => _view = FocusViewState.running);
    } else {
      _entry.forward();
    }
  }

  Future<void> _chooseCustom() async {
    var minutes = _timer.selectedDuration.inMinutes;
    final result = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Custom duration',
                              style: AppTypography.sectionTitle),
                          const SizedBox(height: 20),
                          Text('$minutes minutes',
                              style: AppTypography.pageTitle,
                              textAlign: TextAlign.center),
                          Slider(
                              value: minutes.toDouble(),
                              min: 5,
                              max: 180,
                              divisions: 175,
                              label: '$minutes minutes',
                              semanticFormatterCallback: (value) =>
                                  '${value.round()} minutes',
                              onChanged: (value) =>
                                  update(() => minutes = value.round())),
                          const Text('5–180 minutes',
                              style: AppTypography.caption,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          SenseiPrimaryButton(
                              text: 'Use duration',
                              onPressed: () =>
                                  Navigator.of(context).pop(minutes)),
                        ])))));
    if (result != null && mounted) {
      setState(() {
        _custom = true;
        _timer.selectDuration(Duration(minutes: result));
      });
    }
  }

  Widget _choice(int? minutes, String title, String subtitle) {
    final selected = minutes == null
        ? _custom
        : !_custom && _timer.selectedDuration.inMinutes == minutes;
    void choose() {
      if (minutes == null) {
        _chooseCustom();
      } else {
        setState(() {
          _custom = false;
          _timer.selectDuration(Duration(minutes: minutes));
        });
      }
    }

    return Semantics(
        button: true,
        selected: selected,
        label: '$title, $subtitle',
        excludeSemantics: true,
        onTap: choose,
        child: Material(
            color: selected
                ? AppColors.surfaceHighlight
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
                onTap: choose,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: selected
                                ? AppColors.primaryLight
                                : AppColors.borderMedium,
                            width: selected ? 1.5 : 1)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(title,
                                    style: AppTypography.sectionTitle)),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  size: 20, color: AppColors.primaryLight)
                          ]),
                          const SizedBox(height: 8),
                          Text(subtitle, style: AppTypography.bodyMedium),
                        ])))));
  }

  Widget _setup() => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Focus', style: AppTypography.pageTitle),
            const SizedBox(height: 36),
            const Text('How long do you want to lock in?',
                style: AppTypography.pageTitle),
            const SizedBox(height: 12),
            const Text('Choose a session and settle in.',
                style: AppTypography.bodyLarge),
            const SizedBox(height: 28),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final type in FocusSessionType.values)
                ChoiceChip(
                    label: Text(type.label),
                    selected: _timer.sessionType == type,
                    onSelected: _restoring
                        ? null
                        : (_) => setState(() {
                              _custom = false;
                              _timer.selectSessionType(type);
                            })),
            ]),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, box) {
              final width = MediaQuery.textScalerOf(context).scale(16) > 24
                  ? box.maxWidth
                  : (box.maxWidth - 12) / 2;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                if (_timer.sessionType == FocusSessionType.focus) ...[
                  SizedBox(
                      width: width,
                      child: _choice(25, '25 min', 'Quick Focus')),
                  SizedBox(
                      width: width, child: _choice(45, '45 min', 'Deep Work')),
                  SizedBox(
                      width: width,
                      child: _choice(60, '60 min', 'Long Session')),
                ] else
                  SizedBox(
                      width: width,
                      child: _choice(
                          _timer.sessionType.minutes,
                          '${_timer.sessionType.minutes} min',
                          _timer.sessionType.label)),
                SizedBox(
                    width: width,
                    child: _choice(
                        null,
                        'Custom',
                        _custom
                            ? '${_timer.selectedDuration.inMinutes} minutes'
                            : 'Your own pace')),
              ]);
            }),
            const SizedBox(height: 28),
            SenseiPrimaryButton(
                text: _timer.sessionType == FocusSessionType.focus
                    ? 'Start Focus'
                    : 'Start Break',
                onPressed: _restoring ? null : _start),
            const SizedBox(height: 12),
          ])));
  Widget _active() {
    final isBreak = _timer.sessionType != FocusSessionType.focus;
    final paused = _status == FocusSessionStatus.paused,
        complete = _status == FocusSessionStatus.completed;
    final style = AppTypography.bodyLarge.copyWith(color: focusIvory);
    return SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(children: [
              Text('Focus',
                  style:
                      AppTypography.sectionTitle.copyWith(color: focusIvory)),
              const SizedBox(height: 20),
              AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => FlipClock(
                      key: ValueKey(_timer.clockRevision),
                      seconds: _timer.remainingSeconds)),
              const SizedBox(height: 16),
              Semantics(
                  liveRegion: true,
                  child: Text(
                      complete
                          ? (isBreak ? 'Break complete.' : 'Focus complete.')
                          : paused
                              ? 'Paused'
                              : (isBreak
                                  ? _timer.sessionType.label.toUpperCase()
                                  : 'FOCUS SESSION'),
                      textAlign: TextAlign.center,
                      style: style.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: complete || paused ? 0 : 1.8))),
              if (complete) ...[
                const SizedBox(height: 8),
                Text(
                    isBreak
                        ? 'Ready when you are.'
                        : 'Nice work. Take a moment.',
                    style: style,
                    textAlign: TextAlign.center)
              ],
              const SizedBox(height: 12),
              Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (complete) ...[
                      _sceneButton('Done', _timer.reset),
                      _sceneButton('Start Again', _start)
                    ] else if (paused) ...[
                      _sceneButton('Resume', _timer.resume),
                      _sceneButton('End Session', _timer.reset)
                    ] else ...[
                      _sceneButton('Pause', _timer.pause),
                      _sceneButton('Reset', _timer.reset),
                      _sceneButton('End Session', _timer.reset)
                    ],
                  ]),
            ])));
  }

  Widget _sceneButton(String label, VoidCallback action) => TextButton(
      style: TextButton.styleFrom(
          foregroundColor: focusIvory,
          backgroundColor: focusInk.withValues(alpha: .65),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      onPressed: action,
      child: Text(label, textAlign: TextAlign.center));
  @override
  Widget build(BuildContext context) {
    final setup = _view == FocusViewState.setup;
    return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(fit: StackFit.expand, children: [
          IgnorePointer(
              ignoring: !setup || _restoring,
              child: ExcludeSemantics(
                  excluding: !setup,
                  child: FadeTransition(
                      opacity: ReverseAnimation(_entry),
                      child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: Offset.zero, end: const Offset(0, .06))
                              .animate(_entry),
                          child: _setup())))),
          IgnorePointer(
              ignoring: setup,
              child: ExcludeSemantics(
                  excluding: setup,
                  child: FadeTransition(
                      opacity: _entry,
                      child: Stack(fit: StackFit.expand, children: [
                        SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(0, .04),
                                    end: Offset.zero)
                                .animate(_entry.drive(
                                    CurveTween(curve: Curves.easeOutCubic))),
                            child: FocusScene(
                                moving: _timer.isRunning && _timer.foreground,
                                timer: _timer)),
                        const IgnorePointer(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                              Color(0x70182C3B),
                              Color(0x00182C3B)
                            ],
                                        stops: [
                              0,
                              .55
                            ])))),
                        IgnorePointer(
                            child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 400),
                                color: Colors.black.withValues(
                                    alpha: _status == FocusSessionStatus.paused
                                        ? .3
                                        : 0))),
                        if (_status == FocusSessionStatus.completed)
                          IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: .12, end: 0),
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 1100),
                                  builder: (context, value, _) => ColoredBox(
                                      color: focusIvory.withValues(
                                          alpha: value)))),
                        FadeTransition(
                            opacity: _entry.drive(
                                CurveTween(curve: const Interval(.2, 1))),
                            child: _active()),
                      ])))),
        ]));
  }
}
