import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/utils/compose_image_compress.dart';

void main() {
  group('ComposeImageCompress', () {
    Uint8List _bigPng() {
      final image = img.Image(width: 3000, height: 2000);
      img.fill(image, color: img.ColorRgb8(10, 20, 30));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('skips when useOriginal', () async {
      final bytes = _bigPng();
      final out = await ComposeImageCompress.maybeCompress(
        bytes: bytes,
        filename: 'big.png',
        useOriginal: true,
      );
      expect(out.bytes.length, bytes.length);
      expect(out.filename, 'big.png');
    });

    test('shrinks long edge to default max', () async {
      final bytes = _bigPng();
      final out = await ComposeImageCompress.maybeCompress(
        bytes: bytes,
        filename: 'big.png',
        useOriginal: false,
      );
      final decoded = img.decodeImage(out.bytes)!;
      expect(decoded.width, lessThanOrEqualTo(2000));
      expect(decoded.height, lessThanOrEqualTo(2000));
    });
  });
}
