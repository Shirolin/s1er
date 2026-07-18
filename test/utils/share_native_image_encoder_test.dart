import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/utils/share_native_image_encoder.dart';

import '../helpers/ironpress_test_lib.dart';

Uint8List _tinyPng() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(32, 64, 128));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  setUpAll(ensureIronpressTestNativeLib);

  group('share_native_image_encoder', () {
    test('encodeShareWebpFromPng yields WebP on native when available',
        () async {
      final png = _tinyPng();
      final bytes = await encodeShareWebpFromPng(png);

      if (kIsWeb) {
        expect(bytes, isNull);
        return;
      }

      if (bytes == null) {
        markTestSkipped('ironpress WebP encode unavailable');
        return;
      }

      expect(bytes.length, greaterThan(12));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
      expect(bytes.length, lessThan(png.length));
    });

    test('encodeShareJpegFromPng yields JPEG on native when available',
        () async {
      final png = _tinyPng();
      final bytes = await encodeShareJpegFromPng(png);

      if (kIsWeb) {
        expect(bytes, isNull);
        return;
      }

      if (bytes == null) {
        markTestSkipped('ironpress JPEG encode unavailable');
        return;
      }

      expect(bytes.length, greaterThan(3));
      expect(bytes[0], 0xff);
      expect(bytes[1], 0xd8);
    });

    test('encodeSharePngOptimized returns PNG bytes on native', () async {
      final png = _tinyPng();
      final bytes = await encodeSharePngOptimized(png);

      if (kIsWeb) {
        expect(bytes, png);
        return;
      }

      if (bytes == null) {
        markTestSkipped('ironpress PNG optimize unavailable');
        return;
      }

      expect(bytes.length, greaterThan(8));
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x4e); // N
      expect(bytes[3], 0x47); // G
    });
  });
}
