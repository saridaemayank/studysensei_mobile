import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/focus_timer_controller.dart';

/// Separate, unmodified layers share one canvas and one cover transform.
/// Cloud/foreground replacements need transparency and the sky's canvas size.
class FocusScene extends StatefulWidget {
  final bool moving;
  final FocusTimerController timer;
  const FocusScene({super.key, required this.moving, required this.timer});
  @override
  State<FocusScene> createState() => _FocusSceneState();
}

class _FocusSceneState extends State<FocusScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));
  Size _canvas = const Size(718, 1332);
  ImageStream? _skyStream;
  ImageStreamListener? _skyListener;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
    if (_skyStream == null) {
      _skyListener = ImageStreamListener((info, _) {
        final size =
            Size(info.image.width.toDouble(), info.image.height.toDouble());
        info.dispose();
        if (mounted && size != _canvas) setState(() => _canvas = size);
      }, onError: (Object error, StackTrace? stack) {});
      _skyStream = const AssetImage('assets/images/focus_sky.png')
          .resolve(createLocalImageConfiguration(context));
      _skyStream!.addListener(_skyListener!);
    }
  }

  @override
  void didUpdateWidget(FocusScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.moving &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_motion.isAnimating) _motion.repeat(reverse: true);
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    if (_skyListener != null) _skyStream?.removeListener(_skyListener!);
    _motion.dispose();
    super.dispose();
  }

  Widget layer(String name) => RepaintBoundary(
      child: Image.asset('assets/images/focus_$name.png',
          key: ValueKey('focus-layer-$name'),
          fit: BoxFit.fill,
          width: _canvas.width,
          height: _canvas.height,
          excludeFromSemantics: true));
  @override
  Widget build(BuildContext context) => RepaintBoundary(
          child: Stack(fit: StackFit.expand, children: [
        ClipRect(child: LayoutBuilder(builder: (context, box) {
          final scale = math.max(
              box.maxWidth / _canvas.width, box.maxHeight / _canvas.height);
          return FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              child: SizedBox.fromSize(
                  size: _canvas,
                  child: Stack(fit: StackFit.expand, children: [
                    layer('sky'),
                    AnimatedBuilder(
                        animation: _motion,
                        child: layer('cloud'),
                        builder: (context, child) => Transform.translate(
                            offset: Offset(
                                math.sin(_motion.value * math.pi * 2) *
                                    32 /
                                    scale,
                                0),
                            child: Transform.scale(
                                scale: 1.10 +
                                    math.sin(_motion.value * math.pi) * .01,
                                child: child))),
                    AnimatedBuilder(
                        animation: _motion,
                        child: layer('foreground'),
                        builder: (context, child) => Transform.translate(
                            offset: Offset(
                                0,
                                math.sin(_motion.value * math.pi * 2) *
                                    4 /
                                    scale),
                            child: Transform.scale(
                                scale: 1.02,
                                alignment: Alignment.center,
                                child: child))),
                  ])));
        })),
        IgnorePointer(
            child: AnimatedBuilder(
                animation: widget.timer,
                builder: (context, _) => ColoredBox(
                    color: const Color(0xFFFFD48A)
                        .withValues(alpha: widget.timer.progress * .045)))),
      ]));
}
