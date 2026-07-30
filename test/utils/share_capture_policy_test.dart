import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/utils/share_capture_limits.dart';
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

  test('multi-floor below threshold uses one-shot capture', () {
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 2,
        estimatedCapturePixels: 100,
      ),
      isFalse,
    );
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 4,
        estimatedCapturePixels:
            S1Constants.shareCaptureChunkThresholdPixels - 1,
      ),
      isFalse,
    );
  });

  test('multi-floor above threshold uses scroll slicing', () {
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 2,
        estimatedCapturePixels: S1Constants.shareCaptureChunkThresholdPixels,
      ),
      isTrue,
    );
    expect(
      shouldUseChunkedShareCapture(
        floorCount: 10,
        estimatedCapturePixels: S1Constants.shareCaptureChunkThresholdPixels,
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

  test('advanced hard cap uses injected platform limits', () {
    const overNormal = S1Constants.shareCaptureMaxPixels + 1;
    final mobileLimits = ShareCaptureLimits.mobileAdvanced();

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
        limits: mobileLimits,
      ),
      isFalse,
    );
    expect(
      exceedsShareCaptureHardCap(
        estimatedCapturePixels: mobileLimits.maxPixels + 1,
        advanced: true,
        limits: mobileLimits,
      ),
      isTrue,
    );
  });

  test('desktop advanced allows taller strip slices', () {
    final desktopLimits = ShareCaptureLimits.desktopAdvanced();
    expect(
      shareInFloorChunkLogicalSliceHeight(1.5, limits: desktopLimits),
      5461,
    );
    expect(
      shouldUseInFloorChunking(
        advancedEnabled: true,
        floorLogicalHeight: 5000,
        pixelRatio: 1.5,
        limits: desktopLimits,
      ),
      isFalse,
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

  test('shareCaptureSizeFromLogical rounds physical dimensions', () {
    final size = shareCaptureSizeFromLogical(
      logicalWidth: 600.4,
      logicalHeight: 1000.6,
      pixelRatio: 1.5,
      maxPixels: S1Constants.shareCaptureMaxPixels,
    );
    expect(size.physicalWidth, 901);
    expect(size.physicalHeight, 1501);
    expect(size.totalPixels, 901 * 1501);
  });

  test('formatShareCaptureSizeDetail includes cap', () {
    final size = shareCaptureSizeFromPhysical(
      physicalWidth: 1350,
      physicalHeight: 28400,
      maxPixels: S1Constants.shareCaptureMaxPixels,
    );
    expect(
      formatShareCaptureSizeDetail(size),
      '约 1350×28400 px（38.3M 像素，上限 14.7M 像素）',
    );
    expect(
      formatShareCaptureSizeShort(size),
      '（约 1350×28400 px）',
    );
  });
}
