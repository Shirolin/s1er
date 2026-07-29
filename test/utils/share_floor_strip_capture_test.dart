import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_capture_helpers.dart';
import 'package:s1er/utils/share_capture_policy.dart';
import 'package:s1er/utils/share_floor_strip_capture.dart';

void main() {
  group('scroll capture helpers', () {
    test('effectiveScrollCaptureHeight prefers measured height', () {
      expect(
        effectiveScrollCaptureHeight(
          estimatedHeight: 5000,
          measuredHeight: 4200,
        ),
        4200,
      );
      expect(
        effectiveScrollCaptureHeight(
          estimatedHeight: 5000,
          measuredHeight: 0,
        ),
        5000,
      );
    });

    test('shouldStopScrollCapture detects repeated offset', () {
      expect(
        shouldStopScrollCapture(actualOffset: 100, lastCapturedOffset: 100),
        isTrue,
      );
      expect(
        shouldStopScrollCapture(actualOffset: 100, lastCapturedOffset: 50),
        isFalse,
      );
    });

    test('scrollCaptureLogicalHeightFromStrips sums physical heights', () {
      final logical = scrollCaptureLogicalHeightFromStrips(
        [300, 150],
        pixelRatio: 1.5,
      );
      expect(logical, 300);
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
