import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_jpeg_encoder.dart';

void main() {
  group('flattenRgbaOntoRgb', () {
    test('keeps opaque pixels and fills transparent with background', () {
      final rgba = Uint8List.fromList([
        10, 20, 30, 255, // opaque
        0, 0, 0, 0, // transparent
        100, 0, 0, 128, // 50% red over white
      ]);

      final rgb = flattenRgbaOntoRgb(
        rgba: rgba,
        width: 3,
        height: 1,
        bgR: 255,
        bgG: 255,
        bgB: 255,
      );

      expect(rgb, [
        10, 20, 30,
        255, 255, 255,
        177, 127, 127, // (100*128 + 255*127) ~/ 255
      ]);
    });
  });

  group('encodeShareJpeg', () {
    test('produces a JPEG payload for a tiny card', () {
      final rgba = Uint8List(8 * 8 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 40;
        rgba[i + 1] = 80;
        rgba[i + 2] = 120;
        rgba[i + 3] = 255;
      }
      // Transparent corner pixel
      rgba[3] = 0;

      final bytes = encodeShareJpeg(
        ShareJpegEncodeParams(
          rgbaBytes: rgba,
          width: 8,
          height: 8,
          bgR: 16,
          bgG: 16,
          bgB: 16,
        ),
      );

      expect(bytes.length, greaterThan(32));
      // SOI marker
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xD8);
    });
  });
}
