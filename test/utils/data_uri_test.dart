import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/utils/data_uri.dart';

Uint8List _pngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 80, 80));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('DataUri.normalizeImageUrl', () {
    test('fixes http://data: prefix', () {
      const raw = 'http://data:image/png;base64,AAAA';
      expect(
        DataUri.normalizeImageUrl(raw),
        'data:image/png;base64,AAAA',
      );
    });

    test('fixes https://data: prefix', () {
      const raw = 'https://data:image/png;base64,AAAA';
      expect(
        DataUri.normalizeImageUrl(raw),
        'data:image/png;base64,AAAA',
      );
    });

    test('unescapes HTML entities', () {
      expect(
        DataUri.normalizeImageUrl('https://a.com/x?foo=1&amp;bar=2'),
        'https://a.com/x?foo=1&bar=2',
      );
    });
  });

  group('DataUri.decode', () {
    test('decodes base64 PNG payload', () {
      final bytes = _pngBytes(width: 4, height: 3);
      final dataUri = 'data:image/png;base64,${base64Encode(bytes)}';

      expect(DataUri.decode(dataUri), bytes);
    });

    test('decodes malformed http://data: prefix', () {
      final bytes = _pngBytes(width: 8, height: 2);
      final malformed = 'http://data:image/png;base64,${base64Encode(bytes)}';

      expect(DataUri.decode(malformed), bytes);
    });

    test('returns null for non-data URLs', () {
      expect(
        DataUri.decode('https://example.com/a.png'),
        isNull,
      );
    });
  });
}
