import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Coordinates relative to the complete, orientation-correct displayed image.
/// Letterboxing is never part of this coordinate system.
@immutable
class FocusRegion {
  final double x;
  final double y;
  final double width;
  final double height;

  const FocusRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  })  : assert(x >= 0 && y >= 0 && width > 0 && height > 0),
        assert(x + width <= 1 && y + height <= 1);

  static const fullImage = FocusRegion(x: 0, y: 0, width: 1, height: 1);

  Map<String, double> toJson() =>
      {'x': x, 'y': y, 'width': width, 'height': height};

  bool get isFullImage => x == 0 && y == 0 && width == 1 && height == 1;

  Rect toDisplayRect(Size imageDisplaySize) => Rect.fromLTWH(
        x * imageDisplaySize.width,
        y * imageDisplaySize.height,
        width * imageDisplaySize.width,
        height * imageDisplaySize.height,
      );

  /// [rect] uses image-local coordinates, after subtracting letterbox offsets.
  factory FocusRegion.fromDisplayRect(Rect rect, Size imageDisplaySize) {
    if (imageDisplaySize.isEmpty ||
        !imageDisplaySize.isFinite ||
        !rect.isFinite ||
        rect.isEmpty) {
      throw ArgumentError(
          'A finite image size and nonempty region are required.');
    }
    final left = (rect.left / imageDisplaySize.width).clamp(0.0, 1.0);
    final top = (rect.top / imageDisplaySize.height).clamp(0.0, 1.0);
    final right = (rect.right / imageDisplaySize.width).clamp(left, 1.0);
    final bottom = (rect.bottom / imageDisplaySize.height).clamp(top, 1.0);
    if (right == left || bottom == top) {
      throw ArgumentError('Region must intersect the image.');
    }
    return FocusRegion(
        x: left, y: top, width: right - left, height: bottom - top);
  }
}
