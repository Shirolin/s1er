import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/utils/gallery_image_saver.dart';

Uint8List _tinyPng() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(1, 2, 3));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _tinyJpeg() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// Minimal RIFF/WebP VP8 bitstream header (not a full decodeable image).
Uint8List _webpMagicOnly() {
  return Uint8List.fromList(<int>[
    0x52, 0x49, 0x46, 0x46, // RIFF
    0x08, 0x00, 0x00, 0x00, // size
    0x57, 0x45, 0x42, 0x50, // WEBP
  ]);
}

void main() {
  group('gallery_image_saver magic sniffers', () {
    test('detects PNG / JPEG / WebP signatures', () {
      expect(isPngImageBytes(_tinyPng()), isTrue);
      expect(isJpegImageBytes(_tinyJpeg()), isTrue);
      expect(isWebpImageBytes(_webpMagicOnly()), isTrue);

      expect(isWebpImageBytes(_tinyPng()), isFalse);
      expect(isPngImageBytes(_tinyJpeg()), isFalse);
      expect(isJpegImageBytes(_webpMagicOnly()), isFalse);
    });

    test('rejects short buffers', () {
      expect(isPngImageBytes(Uint8List(0)), isFalse);
      expect(isJpegImageBytes(Uint8List.fromList([0xff])), isFalse);
      expect(isWebpImageBytes(Uint8List(8)), isFalse);
    });
  });
}
