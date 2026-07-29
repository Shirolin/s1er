import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/utils/share_image_stitch.dart';
import 'package:s1er/utils/share_rgba_encoder.dart';

ShareRgbaStrip _solidStrip({
  required int width,
  required int height,
  required int r,
  required int g,
  required int b,
}) {
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    final offset = i * 4;
    bytes[offset] = r;
    bytes[offset + 1] = g;
    bytes[offset + 2] = b;
    bytes[offset + 3] = 255;
  }
  return ShareRgbaStrip(bytes: bytes, width: width, height: height);
}

void main() {
  group('encodePngFromRgbaStrip', () {
    test('preserves dimensions for very tall strips', () async {
      const width = 120;
      const height = 12000;
      final strip = _solidStrip(
        width: width,
        height: height,
        r: 10,
        g: 20,
        b: 30,
      );

      final png = await encodePngFromRgbaStrip(strip);
      final decoded = img.decodePng(png);
      expect(decoded, isNotNull);
      expect(decoded!.width, width);
      expect(decoded.height, height);
    });
  });

  group('scaleRgbaStripToFitPixels', () {
    test('preserves aspect ratio when downscaling', () {
      const width = 900;
      const height = 50000;
      final strip = _solidStrip(
        width: width,
        height: height,
        r: 200,
        g: 100,
        b: 50,
      );

      final scaled = scaleRgbaStripToFitPixels(
        strip,
        maxPixels: 60000000,
      );

      expect(scaled.width * scaled.height, lessThanOrEqualTo(60000000));
      const ratioBefore = width / height;
      final ratioAfter = scaled.width / scaled.height;
      expect(ratioAfter, closeTo(ratioBefore, 0.01));
    });
  });
}
