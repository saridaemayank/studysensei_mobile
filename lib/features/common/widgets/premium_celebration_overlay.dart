import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef PremiumCelebrationTexts = ({String title, String subtitle});

Future<void> showPremiumCelebrationOverlay(
  BuildContext context, {
  PremiumCelebrationTexts? texts,
  Duration autoDismissAfter = const Duration(milliseconds: 2800),
}) async {
  final effectiveTexts = texts ??
      (
        title: "You've unlocked the Sensei Way! 🥋",
        subtitle: 'Premium features are now yours to explore.'
      );

  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'premium-celebration',
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _PremiumCelebrationDialog(
        title: effectiveTexts.title,
        subtitle: effectiveTexts.subtitle,
        autoDismissAfter: autoDismissAfter,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: curved, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

class _PremiumCelebrationDialog extends StatefulWidget {
  const _PremiumCelebrationDialog({
    required this.title,
    required this.subtitle,
    required this.autoDismissAfter,
  });

  final String title;
  final String subtitle;
  final Duration autoDismissAfter;

  @override
  State<_PremiumCelebrationDialog> createState() =>
      _PremiumCelebrationDialogState();
}

class _PremiumCelebrationDialogState extends State<_PremiumCelebrationDialog>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  late final AnimationController _controller;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _cardScale;
  late final List<_ConfettiPiece> _confetti;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _cardOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _cardScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );

    _confetti = _generateConfettiPieces();

    HapticFeedback.mediumImpact();

    _dismissTimer = Timer(widget.autoDismissAfter, () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.pushNamedAndRemoveUntil('/home', (route) => false);
  }

  List<_ConfettiPiece> _generateConfettiPieces() {
    final random = Random(42);
    final colors = [
      const Color(0xFFFFC84A),
      const Color(0xFFF86EC7),
      const Color(0xFF4DA6FF),
      const Color(0xFF9D7BFF),
      const Color(0xFFFF8F6B),
    ];

    return List.generate(36, (index) {
      final color = colors[index % colors.length];
      final startX = random.nextDouble();
      final endX =
          (startX + (random.nextDouble() * 0.4 - 0.2)).clamp(0.05, 0.95);
      final startY = random.nextDouble() * 0.25 + 0.05;
      final endY = startY + random.nextDouble() * 0.6 + 0.25;
      final size = random.nextDouble() * 10 + 6;
      final rotation = random.nextDouble() * pi;
      final startProgress = random.nextDouble() * 0.3;
      final endProgress = (startProgress + 0.55 + random.nextDouble() * 0.3)
          .clamp(startProgress + 0.2, 1.0);

      return _ConfettiPiece(
        startX: startX,
        endX: endX,
        startY: startY,
        endY: endY.clamp(0.6, 1.1),
        color: color,
        size: size,
        rotation: rotation,
        startProgress: startProgress,
        endProgress: endProgress,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConfettiPainter(
                  pieces: _confetti,
                  progress: _controller.value,
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Center(
            child: FadeTransition(
              opacity: _cardOpacity,
              child: ScaleTransition(
                scale: _cardScale,
                child: Container(
                  width: 320,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(
                      theme.brightness == Brightness.dark ? 0.95 : 0.98,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.35),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.85),
                              theme.colorScheme.primary.withOpacity(0.65),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  theme.colorScheme.primary.withOpacity(0.45),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurface.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _navigateToHome,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.startX,
    required this.endX,
    required this.startY,
    required this.endY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.startProgress,
    required this.endProgress,
  });

  final double startX;
  final double endX;
  final double startY;
  final double endY;
  final Color color;
  final double size;
  final double rotation;
  final double startProgress;
  final double endProgress;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.progress,
  });

  final List<_ConfettiPiece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (pieces.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final piece in pieces) {
      final segment = _computeSegmentProgress(
        progress,
        piece.startProgress,
        piece.endProgress,
      );
      if (segment <= 0 || segment >= 1.05) continue;

      final opacity = _opacityForSegment(segment);
      if (opacity <= 0) continue;

      final x = _lerp(piece.startX, piece.endX, segment) * size.width;
      final y = _lerp(piece.startY, piece.endY, segment) * size.height;

      paint.color = piece.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation * segment);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.size,
        height: piece.size * 0.55,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(piece.size * 0.18));
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  double _computeSegmentProgress(
    double value,
    double start,
    double end,
  ) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  double _opacityForSegment(double t) {
    if (t < 0.2) {
      return t / 0.2;
    } else if (t > 0.8) {
      return (1 - t) / 0.2;
    }
    return 1;
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pieces.length != pieces.length;
}
