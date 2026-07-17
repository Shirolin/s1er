import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/share_pixel_ratio.dart';

void main() {
  group('SharePixelRatio.normalize', () {
    test('defaults null/unknown to balanced', () {
      expect(SharePixelRatio.normalize(null), 1.5);
      expect(SharePixelRatio.normalize('x'), 1.5);
    });

    test('keeps allowed values', () {
      expect(SharePixelRatio.normalize(1.5), 1.5);
      expect(SharePixelRatio.normalize(2), 2.0);
      expect(SharePixelRatio.normalize(3.0), 3.0);
    });

    test('snaps legacy ints and nearby values', () {
      expect(SharePixelRatio.normalize(1), 1.5);
      expect(SharePixelRatio.normalize(2.2), 2.0);
      expect(SharePixelRatio.normalize(2.8), 3.0);
    });
  });
}
