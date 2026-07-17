import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_rgba_flatten.dart';

void main() {
  group('flattenRgbaOntoOpaqueRgba', () {
    test('keeps opaque pixels and fills transparent with background', () {
      final rgba = Uint8List.fromList([
        10, 20, 30, 255, // opaque
        0, 0, 0, 0, // transparent
        100, 0, 0, 128, // 50% red over white
      ]);

      final out = flattenRgbaOntoOpaqueRgba(
        rgba: rgba,
        width: 3,
        height: 1,
        bgR: 255,
        bgG: 255,
        bgB: 255,
      );

      expect(out, [
        10, 20, 30, 255,
        255, 255, 255, 255,
        177, 127, 127, 255,
      ]);
    });
  });
}
