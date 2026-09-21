import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/features/sensei/models/focus_region.dart';
import 'package:study_sensei/features/sensei/utils/selection_geometry.dart';

void main() {
  test('Normalize image-local pixels and map to another display size', () {
    final region = FocusRegion.fromDisplayRect(
        const Rect.fromLTWH(40, 140, 110, 72), const Size(200, 400));
    expect(region.x, closeTo(.20, 1e-10));
    expect(region.y, closeTo(.35, 1e-10));
    expect(region.width, closeTo(.55, 1e-10));
    expect(region.height, closeTo(.18, 1e-10));
    final display = region.toDisplayRect(const Size(100, 200));
    expect(display.left, closeTo(20, 1e-10));
    expect(display.top, closeTo(70, 1e-10));
    expect(display.width, closeTo(55, 1e-10));
    expect(display.height, closeTo(36, 1e-10));
  });

  test('Contain excludes horizontal and vertical letterboxing', () {
    expect(containedImageBounds(const Size(400, 200), const Size(300, 400)),
        const Rect.fromLTWH(0, 125, 300, 150));
    expect(containedImageBounds(const Size(100, 800), const Size(300, 400)),
        const Rect.fromLTWH(125, 0, 50, 400));
    final bounds =
        containedImageBounds(const Size(400, 200), const Size(300, 400));
    final region = FocusRegion.fromDisplayRect(
        const Rect.fromLTWH(75, 162.5, 150, 75).shift(-bounds.topLeft),
        bounds.size);
    expect(region.x, .25);
    expect(region.y, .25);
    expect(region.width, .5);
    expect(region.height, .5);
  });

  test('Full image and invalid regions', () {
    final full = FocusRegion.fullImage;
    expect([full.x, full.y, full.width, full.height], [0, 0, 1, 1]);
    expect(full.toDisplayRect(const Size(280, 500)),
        const Rect.fromLTWH(0, 0, 280, 500));
    expect(() => FocusRegion.fromDisplayRect(Rect.zero, const Size(100, 100)),
        throwsArgumentError);
    expect(
        () => FocusRegion.fromDisplayRect(
            const Rect.fromLTWH(150, 0, 10, 10), const Size(100, 100)),
        throwsArgumentError);
  });

  test('Creation and movement clamp at all image edges', () {
    const size = Size(200, 400);
    final created =
        createSelection(const Offset(190, 390), const Offset(300, 600), size);
    expect(created, const Rect.fromLTWH(168, 368, 32, 32));
    expect(moveSelection(created, const Offset(-1000, -1000), size),
        const Rect.fromLTWH(0, 0, 32, 32));
    expect(moveSelection(created, const Offset(1000, 1000), size), created);
    final clipped = FocusRegion.fromDisplayRect(
        const Rect.fromLTWH(-5, -10, 210, 420), size);
    expect(clipped.isFullImage, isTrue);
  });

  test('All resize corners clamp and cannot invert or collapse', () {
    const size = Size(200, 400);
    const rect = Rect.fromLTWH(50, 100, 100, 200);
    for (final corner in SelectionCorner.values) {
      for (final point in [
        const Offset(-1000, -1000),
        const Offset(1000, 1000)
      ]) {
        final resized = resizeSelection(rect, corner, point, size);
        expect(resized.left, greaterThanOrEqualTo(0));
        expect(resized.top, greaterThanOrEqualTo(0));
        expect(resized.right, lessThanOrEqualTo(size.width));
        expect(resized.bottom, lessThanOrEqualTo(size.height));
        expect(resized.width, greaterThanOrEqualTo(32));
        expect(resized.height, greaterThanOrEqualTo(32));
      }
    }
    final narrow =
        createSelection(Offset.zero, const Offset(2, 100), const Size(20, 400));
    expect(narrow.width, 20);
  });
}
