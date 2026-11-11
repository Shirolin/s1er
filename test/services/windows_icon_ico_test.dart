import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:s1er/services/windows_icon_ico.dart';

void main() {
  test('builds a multi-size ICO that decodes back', () {
    final source = img.Image(width: 128, height: 128)
      ..clear(img.ColorRgba8(20, 120, 220, 255));
    final png = Uint8List.fromList(img.encodePng(source));

    final ico = buildWindowsIco(png);

    expect(ico.length, greaterThan(0));
    // ICONDIR: reserved(2) type(2) count(2), little-endian.
    expect(ico[0] | (ico[1] << 8), 0);
    expect(ico[2] | (ico[3] << 8), 1);
    expect(ico[4] | (ico[5] << 8), kWindowsIconSizes.length);

    final decoded = img.decodeIco(ico);
    expect(decoded, isNotNull);
    expect(kWindowsIconSizes, contains(decoded!.width));
  });
}
