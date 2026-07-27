import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/utils/share_capture_policy.dart';

void main() {
  test('single short card uses one-shot capture', () {
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 1,
        estimatedCapturePixels: 1000,
      ),
      isFalse,
    );
  });

  test('multi-floor always chunks', () {
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 2,
        estimatedCapturePixels: 100,
      ),
      isTrue,
    );
  });

  test('tall single floor chunks past threshold', () {
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 1,
        estimatedCapturePixels: S1Constants.shareCaptureChunkThresholdPixels,
      ),
      isTrue,
    );
  });

  test('hard cap detection', () {
    expect(
      exceedsShareCaptureHardCap(
        estimatedCapturePixels: S1Constants.shareCaptureMaxPixels,
      ),
      isFalse,
    );
    expect(
      exceedsShareCaptureHardCap(
        estimatedCapturePixels: S1Constants.shareCaptureMaxPixels + 1,
      ),
      isTrue,
    );
  });

  test('advanced hard cap is higher than normal', () {
    const overNormal = S1Constants.shareCaptureMaxPixels + 1;
    expect(
      exceedsShareCaptureHardCap(
        estimatedCapturePixels: overNormal,
        advanced: false,
      ),
      isTrue,
    );
    expect(
      exceedsShareCaptureHardCap(
        estimatedCapturePixels: overNormal,
        advanced: true,
      ),
      isFalse,
    );
    expect(
      exceedsShareCaptureHardCap(
        estimatedCapturePixels: S1Constants.shareCaptureMaxPixelsAdvanced + 1,
        advanced: true,
      ),
      isTrue,
    );
  });

  test('in-floor chunking requires advanced mode and tall floor', () {
    expect(
      shouldUseInFloorChunking(
        advancedEnabled: false,
        floorLogicalHeight: 10000,
        pixelRatio: 1.5,
      ),
      isFalse,
    );
    expect(
      shouldUseInFloorChunking(
        advancedEnabled: true,
        floorLogicalHeight: 1000,
        pixelRatio: 1.5,
      ),
      isFalse,
    );
    expect(
      shouldUseInFloorChunking(
        advancedEnabled: true,
        floorLogicalHeight: 5000,
        pixelRatio: 1.5,
      ),
      isTrue,
    );
  });

  test('in-floor slice height stays within GPU strip budget', () {
    expect(shareInFloorChunkLogicalSliceHeight(1.5), 2730);
    expect(shareInFloorChunkLogicalSliceHeight(2), 2048);
    expect(shareInFloorChunkLogicalSliceHeight(3), 1365);
  });

  test('in-floor slice count for tall floors', () {
    expect(
      inFloorChunkSliceCount(floorLogicalHeight: 5000, pixelRatio: 1.5),
      2,
    );
    expect(
      inFloorChunkSliceCount(floorLogicalHeight: 2730, pixelRatio: 1.5),
      1,
    );
    expect(
      inFloorChunkSliceCount(floorLogicalHeight: 2731, pixelRatio: 1.5),
      2,
    );
  });

  test('soft floor cap', () {
    expect(
      canAddShareFloor(currentCount: S1Constants.shareMaxSelectedFloors - 1),
      isTrue,
    );
    expect(
      canAddShareFloor(currentCount: S1Constants.shareMaxSelectedFloors),
      isFalse,
    );
  });

  test('estimate pixels scales with ratio', () {
    final at1 = estimateShareCapturePixels(
      logicalWidth: 600,
      logicalHeight: 1000,
      pixelRatio: 1,
    );
    final at2 = estimateShareCapturePixels(
      logicalWidth: 600,
      logicalHeight: 1000,
      pixelRatio: 2,
    );
    expect(at2, at1 * 4);
  });
}
