import 'dart:math' as math;
import 'package:flutter/painting.dart';

enum SelectionCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Shared by painting, hit testing and normalization: excludes letterboxing.
Rect containedImageBounds(Size image, Size viewport) {
  final fitted = applyBoxFit(BoxFit.contain, image, viewport);
  return Alignment.center.inscribe(fitted.destination, Offset.zero & viewport);
}

Offset clampImagePoint(Offset point, Size size) => Offset(
      point.dx.clamp(0.0, size.width),
      point.dy.clamp(0.0, size.height),
    );

Rect createSelection(Offset start, Offset end, Size size) {
  final a = clampImagePoint(start, size);
  final b = clampImagePoint(end, size);
  final width = math.max((a.dx - b.dx).abs(), math.min(32.0, size.width));
  final height = math.max((a.dy - b.dy).abs(), math.min(32.0, size.height));
  return Rect.fromLTWH(
    math.min(a.dx, b.dx).clamp(0.0, size.width - width),
    math.min(a.dy, b.dy).clamp(0.0, size.height - height),
    width,
    height,
  );
}

Rect moveSelection(Rect rect, Offset delta, Size size) => Rect.fromLTWH(
      (rect.left + delta.dx).clamp(0.0, math.max(0.0, size.width - rect.width)),
      (rect.top + delta.dy)
          .clamp(0.0, math.max(0.0, size.height - rect.height)),
      rect.width,
      rect.height,
    );

Rect resizeSelection(
    Rect rect, SelectionCorner corner, Offset point, Size size) {
  // Preserve a smaller normalized region after a viewport change as well.
  final minWidth = math.min(rect.width, math.min(32.0, size.width));
  final minHeight = math.min(rect.height, math.min(32.0, size.height));
  final left =
      corner == SelectionCorner.topLeft || corner == SelectionCorner.bottomLeft;
  final top =
      corner == SelectionCorner.topLeft || corner == SelectionCorner.topRight;
  return Rect.fromLTRB(
    left ? point.dx.clamp(0.0, rect.right - minWidth) : rect.left,
    top ? point.dy.clamp(0.0, rect.bottom - minHeight) : rect.top,
    left ? rect.right : point.dx.clamp(rect.left + minWidth, size.width),
    top ? rect.bottom : point.dy.clamp(rect.top + minHeight, size.height),
  );
}

Offset selectionCornerPosition(Rect rect, SelectionCorner corner) =>
    switch (corner) {
      SelectionCorner.topLeft => rect.topLeft,
      SelectionCorner.topRight => rect.topRight,
      SelectionCorner.bottomLeft => rect.bottomLeft,
      SelectionCorner.bottomRight => rect.bottomRight,
    };
