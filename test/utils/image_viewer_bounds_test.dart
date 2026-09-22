import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/image_viewer_bounds.dart';

void main() {
  group('clampImageViewerTranslation', () {
    // 视口 400x800，图片 1000x8000，scale 1.0：
    // 内容 1000x8000 均大于视口 → 两轴钳制。
    // x ∈ [400 - 1000, 0] = [-600, 0]，y ∈ [800 - 8000, 0] = [-7200, 0]。
    (double, double) clamp({
      double scale = 1.0,
      required double tx,
      required double ty,
      double viewportWidth = 400,
      double viewportHeight = 800,
      double imageWidth = 1000,
      double imageHeight = 8000,
    }) {
      return clampImageViewerTranslation(
        scale: scale,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        tx: tx,
        ty: ty,
      );
    }

    test('content larger than viewport clamps both axes', () {
      expect(clamp(tx: -100, ty: -500), (-100.0, -500.0));
    });

    test('clamps to min bound (content bottom/right edge reached)', () {
      expect(clamp(tx: -9999, ty: -99999), (-600.0, -7200.0));
    });

    test('clamps to max bound (content top/left edge reached)', () {
      expect(clamp(tx: 123, ty: 45), (0.0, 0.0));
    });

    test('is idempotent exactly on the bounds', () {
      final (x, y) = clamp(tx: -600, ty: -7200);
      expect((x, y), (-600.0, -7200.0));
      final (x2, y2) = clamp(tx: 0, ty: 0);
      expect((x2, y2), (0.0, 0.0));
      // 对钳制结果再次钳制必须逐位相等（listener 幂等终止的前提）。
      expect(clamp(tx: x, ty: y), (x, y));
    });

    test('clamps each axis independently', () {
      // x 越界、y 在界内。
      expect(clamp(tx: -5000, ty: -300), (-600.0, -300.0));
      // y 越界、x 在界内。
      expect(clamp(tx: -300, ty: -50000), (-300.0, -7200.0));
    });

    test('centers axis when content fits viewport', () {
      // scale 0.1 → 内容 100x800：x 轴居中 (400-100)/2 = 150；
      // y 轴内容恰好等于视口 → 也居中 = 0。
      final (x, y) = clamp(scale: 0.1, tx: -999, ty: 42);
      expect(x, 150.0);
      expect(y, 0.0);
    });

    test('centers both axes when content smaller than viewport', () {
      // 400x800 视口，200x200 图片 scale 0.5 → 内容 100x100。
      final (x, y) = clamp(
        scale: 0.5,
        tx: 77,
        ty: -33,
        imageWidth: 200,
        imageHeight: 200,
      );
      expect(x, (400 - 100) / 2);
      expect(y, (800 - 100) / 2);
    });

    test('scales bounds proportionally with scale', () {
      // scale 2 → 内容 2000x16000：x ∈ [-1600, 0]，y ∈ [-15200, 0]。
      expect(clamp(scale: 2, tx: -9999, ty: -99999), (-1600.0, -15200.0));
    });
  });
}
