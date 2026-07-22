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
        estimatedCapturePixels:
            S1Constants.shareCaptureChunkThresholdPixels,
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
