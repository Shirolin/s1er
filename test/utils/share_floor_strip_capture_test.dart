import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_capture_policy.dart';

void main() {
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
