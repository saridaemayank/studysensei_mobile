import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/focus_region.dart';
import '../utils/selection_geometry.dart';

/// Only the overlay changes during a drag. The decoded image is reused.
class FocusRegionEditor extends StatefulWidget {
  final ui.Image image;
  final FocusRegion? region;
  final ValueChanged<FocusRegion> onChanged;

  const FocusRegionEditor(
      {super.key,
      required this.image,
      required this.region,
      required this.onChanged});

  @override
  State<FocusRegionEditor> createState() => _FocusRegionEditorState();
}

class _FocusRegionEditorState extends State<FocusRegionEditor> {
  Offset? _down;
  Rect? _initial;
  Rect? _dragBounds;
  SelectionCorner? _corner;
  bool _moving = false;

  Rect _handleTarget(Offset point, Size viewport) => Rect.fromLTWH(
        (point.dx - 24).clamp(0.0, math.max(0.0, viewport.width - 48)),
        (point.dy - 24).clamp(0.0, math.max(0.0, viewport.height - 48)),
        math.min(48, viewport.width),
        math.min(48, viewport.height),
      );

  void _start(Offset point, Rect bounds, Size viewport) {
    _down = null;
    _dragBounds = bounds;
    _initial = widget.region?.toDisplayRect(bounds.size);
    _corner = null;
    _moving = false;
    final local = point - bounds.topLeft;
    // Full image is a mode, not a crop: dragging can immediately replace it.
    if (_initial != null && !widget.region!.isFullImage) {
      double nearest = double.infinity;
      for (final corner in SelectionCorner.values) {
        final distance =
            (selectionCornerPosition(_initial!, corner) - local).distance;
        if (distance <= nearest &&
            _handleTarget(
                    selectionCornerPosition(_initial!, corner) + bounds.topLeft,
                    viewport)
                .contains(point)) {
          nearest = distance;
          _corner = corner;
        }
      }
    }
    if (_corner == null && !bounds.contains(point)) return;
    _down = clampImagePoint(local, bounds.size);
    _moving = _corner == null &&
        _initial != null &&
        !widget.region!.isFullImage &&
        _initial!.contains(local);
  }

  void _update(Offset point, Rect bounds) {
    if (_down == null || bounds != _dragBounds) return;
    final local = clampImagePoint(point - bounds.topLeft, bounds.size);
    final Rect rect;
    if (_corner != null) {
      rect = resizeSelection(
          _initial!,
          _corner!,
          selectionCornerPosition(_initial!, _corner!) + local - _down!,
          bounds.size);
    } else if (_moving) {
      rect = moveSelection(_initial!, local - _down!, bounds.size);
    } else {
      if ((local - _down!).distance < 4) return;
      rect = createSelection(_down!, local, bounds.size);
    }
    widget.onChanged(FocusRegion.fromDisplayRect(rect, bounds.size));
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final bounds = containedImageBounds(
          Size(widget.image.width.toDouble(), widget.image.height.toDouble()),
          constraints.biggest,
        );
        final selection =
            widget.region?.toDisplayRect(bounds.size).shift(bounds.topLeft);
        return GestureDetector(
          key: const ValueKey('selection-canvas'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) =>
              _start(details.localPosition, bounds, constraints.biggest),
          onPanUpdate: (details) => _update(details.localPosition, bounds),
          onPanEnd: (_) => _down = null,
          onPanCancel: () => _down = null,
          child: Stack(fit: StackFit.expand, children: [
            Positioned.fromRect(
              rect: bounds,
              child: RepaintBoundary(
                  child: RawImage(
                key: const ValueKey('selection-image'),
                image: widget.image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              )),
            ),
            Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(
              painter: _SelectionPainter(
                  bounds, selection, widget.region?.isFullImage ?? false),
            ))),
            if (selection != null && !widget.region!.isFullImage)
              for (final corner in SelectionCorner.values)
                Positioned.fromRect(
                  rect: _handleTarget(
                      selectionCornerPosition(selection, corner),
                      constraints.biggest),
                  child: IgnorePointer(
                      child: Semantics(
                    label: switch (corner) {
                      SelectionCorner.topLeft => 'Top left resize handle',
                      SelectionCorner.topRight => 'Top right resize handle',
                      SelectionCorner.bottomLeft => 'Bottom left resize handle',
                      SelectionCorner.bottomRight =>
                        'Bottom right resize handle',
                    },
                    child: const SizedBox.expand(),
                  )),
                ),
          ]),
        );
      });
}

class _SelectionPainter extends CustomPainter {
  final Rect imageBounds;
  final Rect? selection;
  final bool fullImage;

  _SelectionPainter(this.imageBounds, this.selection, this.fullImage);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = selection;
    if (rect == null) return;
    canvas.save();
    canvas.clipRect(imageBounds);
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageBounds)
      ..addRect(rect);
    canvas.drawPath(
        shade, Paint()..color = Colors.black.withValues(alpha: 0.42));
    canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.restore();
    if (!fullImage) {
      for (final corner in SelectionCorner.values) {
        final point = selectionCornerPosition(rect, corner);
        canvas.drawCircle(point, 6, Paint()..color = AppColors.primary);
        canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      imageBounds != oldDelegate.imageBounds ||
      selection != oldDelegate.selection ||
      fullImage != oldDelegate.fullImage;
}
