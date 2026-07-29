import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/share_pixel_ratio.dart';

void main() {
  group('SharePixelRatio.normalize', () {
    test('defaults null/unknown to balanced', () {
      expect(SharePixelRatio.normalize(null), 1.5);
      expect(SharePixelRatio.normalize('x'), 1.5);
    });

    test('keeps allowed values', () {
      expect(SharePixelRatio.normalize(1.25), 1.25);
      expect(SharePixelRatio.normalize(1.5), 1.5);
      expect(SharePixelRatio.normalize(2), 2.0);
      expect(SharePixelRatio.normalize(3.0), 3.0);
    });

    test('snaps legacy ints and nearby values', () {
      expect(SharePixelRatio.normalize(1), 1.25);
      expect(SharePixelRatio.normalize(2.2), 2.0);
      expect(SharePixelRatio.normalize(2.8), 3.0);
    });
  });

  group('SharePixelRatio export metadata', () {
    test('exportWidthPx uses logical card width', () {
      expect(SharePixelRatio.exportWidthPx(1.25), 750);
      expect(SharePixelRatio.exportWidthPx(1.5), 900);
      expect(SharePixelRatio.exportWidthPx(2), 1200);
      expect(SharePixelRatio.exportWidthPx(3), 1800);
    });

    test('subtitleFor reflects selected option', () {
      expect(
        SharePixelRatio.subtitleFor(1.5),
        '约 900px 宽，默认推荐',
      );
      expect(
        SharePixelRatio.subtitleFor(3),
        '约 1800px 宽，体积最大',
      );
    });
  });
}
