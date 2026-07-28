import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/utils/share_capture_limits.dart';

void main() {
  group('ShareCaptureLimits.forCurrentPlatform', () {
    test('normal mode uses standard cap and strip', () {
      final limits = ShareCaptureLimits.forCurrentPlatform(advanced: false);
      expect(limits.maxPixels, S1Constants.shareCaptureMaxPixels);
      expect(
        limits.maxStripPhysicalPx,
        S1Constants.shareInFloorChunkMaxStripPhysicalPx,
      );
    });
  });

  group('advanced tier constants', () {
    test('mobile advanced', () {
      final limits = ShareCaptureLimits.mobileAdvanced();
      expect(limits.maxPixels, 8192 * 5400);
      expect(limits.maxStripPhysicalPx, 4096);
    });

    test('desktop advanced', () {
      final limits = ShareCaptureLimits.desktopAdvanced();
      expect(limits.maxPixels, 16384 * 3600);
      expect(limits.maxStripPhysicalPx, 8192);
    });

    test('web advanced', () {
      final limits = ShareCaptureLimits.webAdvanced();
      expect(limits.maxPixels, 8192 * 3600);
      expect(limits.maxStripPhysicalPx, 4096);
    });

    test('desktop advanced exceeds legacy advanced cap', () {
      expect(
        ShareCaptureLimits.desktopAdvanced().maxPixels,
        greaterThan(S1Constants.shareCaptureMaxPixelsAdvanced),
      );
    });
  });
}
