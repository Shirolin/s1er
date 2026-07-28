import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_capture_policy.dart';
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
    test('clamps to remaining logical height in physical pixels', () {
      const pixelRatio = 2.0;
      const remaining = 3.0;
      final strip = _strip(width: 4, height: 10, fill: 1);
      final maxPhysicalHeight =
          (remaining * pixelRatio).round().clamp(1, strip.height);

      final cropped = cropStripToPhysicalHeight(strip, maxPhysicalHeight);
      expect(cropped.height, 6);
      expect(cropped.width, 4);
    });
  });

  group('inFloorChunkSliceCount', () {
    test('returns zero for non-positive height', () {
      expect(
        inFloorChunkSliceCount(floorLogicalHeight: 0, pixelRatio: 1.5),
        0,
      );
      expect(
        inFloorChunkSliceCount(floorLogicalHeight: -10, pixelRatio: 1.5),
        0,
      );
    });

    test('ceil-divides floor height by slice height', () {
      final sliceHeight = shareInFloorChunkLogicalSliceHeight(1.5);
      expect(
        inFloorChunkSliceCount(
          floorLogicalHeight: sliceHeight.toDouble(),
          pixelRatio: 1.5,
        ),
        1,
      );
      expect(
        inFloorChunkSliceCount(
          floorLogicalHeight: sliceHeight + 1.0,
          pixelRatio: 1.5,
        ),
        2,
      );
    });
  });
}
