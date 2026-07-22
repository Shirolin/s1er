import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_image_stitch.dart';

void main() {
  test('stitches two strips vertically', () {
    // 2x1 red + 2x1 blue → 2x2
    final top = ShareRgbaStrip(
      bytes: Uint8List.fromList([
        255, 0, 0, 255, //
        255, 0, 0, 255,
      ]),
      width: 2,
      height: 1,
    );
    final bottom = ShareRgbaStrip(
      bytes: Uint8List.fromList([
        0, 0, 255, 255, //
        0, 0, 255, 255,
      ]),
      width: 2,
      height: 1,
    );

    final out = stitchRgbaVertically([top, bottom]);
    expect(out.width, 2);
    expect(out.height, 2);
    expect(out.bytes.length, 2 * 2 * 4);
    // First row red
    expect(out.bytes[0], 255);
    expect(out.bytes[1], 0);
    expect(out.bytes[2], 0);
    // Second row blue
    expect(out.bytes[8], 0);
    expect(out.bytes[9], 0);
    expect(out.bytes[10], 255);
  });

  test('rejects width mismatch', () {
    final a = ShareRgbaStrip(
      bytes: Uint8List(4),
      width: 1,
      height: 1,
    );
    final b = ShareRgbaStrip(
      bytes: Uint8List(8),
      width: 2,
      height: 1,
    );
    expect(() => stitchRgbaVertically([a, b]), throwsArgumentError);
  });

  test('rejects empty list', () {
    expect(() => stitchRgbaVertically([]), throwsArgumentError);
  });
}
