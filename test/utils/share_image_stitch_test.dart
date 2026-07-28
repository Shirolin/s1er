import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_image_stitch.dart';

ShareRgbaStrip _strip({
  required int width,
  required int height,
  required int fill,
}) {
  final bytes = Uint8List(width * height * 4);
  if (fill != 0) {
    bytes.fillRange(0, bytes.length, fill);
  }
  return ShareRgbaStrip(bytes: bytes, width: width, height: height);
}

void main() {
  group('cropStripToPhysicalHeight', () {
    test('returns strip unchanged when within max height', () {
      final strip = _strip(width: 2, height: 4, fill: 1);
      final cropped = cropStripToPhysicalHeight(strip, 4);
      expect(identical(cropped, strip), isTrue);
    });

    test('truncates bottom rows when taller than max', () {
      final strip = _strip(width: 2, height: 4, fill: 1);
      final cropped = cropStripToPhysicalHeight(strip, 2);
      expect(cropped.width, 2);
      expect(cropped.height, 2);
      expect(cropped.bytes.length, 2 * 2 * 4);
    });

    test('rejects non-positive max height', () {
      final strip = _strip(width: 2, height: 2, fill: 0);
      expect(
        () => cropStripToPhysicalHeight(strip, 0),
        throwsArgumentError,
      );
    });
  });

  group('VerticalRgbaComposer', () {
    test('appendStrip builds combined bitmap', () {
      final composer = VerticalRgbaComposer.fromEstimatedPhysicalSize(
        estimatedPhysicalHeight: 4,
      );
      composer.appendStrip(_strip(width: 2, height: 1, fill: 1));
      composer.appendStrip(_strip(width: 2, height: 2, fill: 2));

      final out = composer.build();
      expect(out.width, 2);
      expect(out.height, 3);
      expect(out.bytes.length, 2 * 3 * 4);
      expect(out.bytes.first, 1);
      expect(out.bytes[2 * 4], 2);
    });

    test('first strip sets width', () {
      final composer = VerticalRgbaComposer();
      composer.appendStrip(_strip(width: 3, height: 1, fill: 0));
      expect(composer.width, 3);
    });

    test('rejects width mismatch after first strip', () {
      final composer = VerticalRgbaComposer.fromEstimatedPhysicalSize(
        estimatedPhysicalHeight: 2,
      );
      composer.appendStrip(_strip(width: 2, height: 1, fill: 0));
      expect(
        () => composer.appendStrip(_strip(width: 3, height: 1, fill: 0)),
        throwsArgumentError,
      );
    });

    test('grows buffer when estimate is too small', () {
      final composer = VerticalRgbaComposer.fromEstimatedPhysicalSize(
        estimatedPhysicalHeight: 1,
      );
      composer.appendStrip(_strip(width: 2, height: 1, fill: 0));
      composer.appendStrip(_strip(width: 2, height: 1, fill: 0));

      final out = composer.build();
      expect(out.width, 2);
      expect(out.height, 2);
    });
  });
}
