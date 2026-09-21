import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Illustration-inspired colors scoped to the Focus clock.
const focusIvory = Color(0xFFFFF2D5);
const focusInk = Color(0xFF182C3B);

class FlipClock extends StatelessWidget {
  final int seconds;
  const FlipClock({super.key, required this.seconds});
  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final digits =
        '${minutes.toString().padLeft(2, '0')}${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
        label: '$minutes minutes ${seconds % 60} seconds remaining',
        excludeSemantics: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = math.min(
              58.0,
              (constraints.maxWidth - 24 - (digits.length - 1) * 6) /
                  digits.length);
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < digits.length; i++) ...[
              if (i == digits.length - 2)
                SizedBox(
                    width: 24,
                    child: Text(':',
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                            fontSize: width * .7,
                            color: focusIvory,
                            fontWeight: FontWeight.bold))),
              if (i > 0 && i != digits.length - 2) const SizedBox(width: 6),
              SizedBox(
                  width: width,
                  height: width * 1.42,
                  child: FlipDigit(
                      key: ValueKey('focus-digit-$i'), digit: digits[i])),
            ],
          ]);
        }));
  }
}

class FlipDigit extends StatefulWidget {
  final String digit;
  const FlipDigit({super.key, required this.digit});
  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 340), value: 1);
  late String _old = widget.digit;
  @override
  void didUpdateWidget(FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _old = oldWidget.digit;
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Widget _half(String digit, bool top, double height) => ClipRect(
      child: OverflowBox(
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          minHeight: height,
          maxHeight: height,
          child: SizedBox(
              height: height,
              child: Center(
                  child: Text(digit,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: height * .72,
                          fontWeight: FontWeight.w600,
                          color: focusInk,
                          height: 1))))));
  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        Widget half(String digit, bool top) => SizedBox(
            height: h / 2,
            width: box.maxWidth,
            child: ColoredBox(color: focusIvory, child: _half(digit, top, h)));
        return DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 4))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      final t = _animation.value;
                      return Stack(children: [
                        Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: half(widget.digit, true)),
                        Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: half(t < 1 ? _old : widget.digit, false)),
                        if (t < .5)
                          Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Transform(
                                  alignment: Alignment.bottomCenter,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, .002)
                                    ..rotateX(-math.pi * t),
                                  child: half(_old, true))),
                        if (t >= .5 && t < 1)
                          Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, .002)
                                    ..rotateX(math.pi * (1 - t)),
                                  child: half(widget.digit, false))),
                        Positioned(
                            top: h / 2 - .5,
                            left: 0,
                            right: 0,
                            child: const SizedBox(
                                height: 1,
                                child: ColoredBox(color: Color(0x55776D59)))),
                      ]);
                    })));
      }));
}
