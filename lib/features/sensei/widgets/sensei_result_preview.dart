import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/sensei_image_selection.dart';
import '../models/focus_region.dart';
import '../utils/selection_geometry.dart';

/// A bounded display-only decode; the request's image and coordinates are untouched.
class SenseiResultPreview extends StatefulWidget {
  final SenseiImageSelection selection;
  final Color accent;
  const SenseiResultPreview(
      {super.key, required this.selection, required this.accent});
  @override
  State<SenseiResultPreview> createState() => _SenseiResultPreviewState();
}

class _SenseiResultPreviewState extends State<SenseiResultPreview> {
  ui.Image? _image;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SenseiResultPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection.image != widget.selection.image) {
      _image?.dispose();
      _image = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    ui.Codec? codec;
    try {
      final bytes = await widget.selection.image.readAsBytes();
      if (!mounted || generation != _generation) return;
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
          buffer,
          getTargetSize: (width, height) => width >= height
              ? ui.TargetImageSize(width: math.min(width, 640))
              : ui.TargetImageSize(height: math.min(height, 640)));
      final image = (await codec.getNextFrame()).image;
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      // Preview is optional: a read failure never hides the tutor's response.
    } finally {
      codec?.dispose();
    }
  }

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Semantics(
          image: true,
          label: 'Your problem. Selected area outlined.',
          child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: AppColors.surface,
                child: SizedBox(
                    height: 112,
                    width: double.infinity,
                    child: CustomPaint(
                      foregroundPainter: _RegionPainter(
                          Size(image.width.toDouble(), image.height.toDouble()),
                          widget.selection.focusRegion,
                          widget.accent),
                      child: RawImage(image: image, fit: BoxFit.contain),
                    )),
              )),
        ));
  }
}

class _RegionPainter extends CustomPainter {
  final Size imageSize;
  final FocusRegion region;
  final Color accent;
  _RegionPainter(this.imageSize, this.region, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = containedImageBounds(imageSize, size);
    final rect = region.toDisplayRect(bounds.size).shift(bounds.topLeft);
    canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent);
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.imageSize != imageSize ||
      oldDelegate.region != region ||
      oldDelegate.accent != accent;
}
