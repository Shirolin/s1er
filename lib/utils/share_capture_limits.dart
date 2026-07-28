import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../config/constants.dart';

/// Platform-tier pixel / strip limits for share-card capture.
///
/// Normal mode always uses [S1Constants.shareCaptureMaxPixels].
/// Advanced mode uses higher per-platform ceilings.
class ShareCaptureLimits {
  const ShareCaptureLimits({
    required this.maxPixels,
    required this.maxStripPhysicalPx,
  });

  final int maxPixels;
  final int maxStripPhysicalPx;

  static const int advancedMaxPixelsMobile = 8192 * 5400;
  static const int advancedMaxPixelsDesktop = 16384 * 3600;
  static const int advancedMaxPixelsWeb = 8192 * 3600;

  static const int advancedMaxStripPhysicalPxMobile = 4096;
  static const int advancedMaxStripPhysicalPxDesktop = 8192;
  static const int advancedMaxStripPhysicalPxWeb = 4096;

  static ShareCaptureLimits forCurrentPlatform({required bool advanced}) {
    if (!advanced) {
      return const ShareCaptureLimits(
        maxPixels: S1Constants.shareCaptureMaxPixels,
        maxStripPhysicalPx: S1Constants.shareInFloorChunkMaxStripPhysicalPx,
      );
    }
    if (kIsWeb) {
      return const ShareCaptureLimits(
        maxPixels: advancedMaxPixelsWeb,
        maxStripPhysicalPx: advancedMaxStripPhysicalPxWeb,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return const ShareCaptureLimits(
          maxPixels: advancedMaxPixelsDesktop,
          maxStripPhysicalPx: advancedMaxStripPhysicalPxDesktop,
        );
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return const ShareCaptureLimits(
          maxPixels: advancedMaxPixelsMobile,
          maxStripPhysicalPx: advancedMaxStripPhysicalPxMobile,
        );
    }
  }

  static ShareCaptureLimits mobileAdvanced() => const ShareCaptureLimits(
        maxPixels: advancedMaxPixelsMobile,
        maxStripPhysicalPx: advancedMaxStripPhysicalPxMobile,
      );

  static ShareCaptureLimits desktopAdvanced() => const ShareCaptureLimits(
        maxPixels: advancedMaxPixelsDesktop,
        maxStripPhysicalPx: advancedMaxStripPhysicalPxDesktop,
      );

  static ShareCaptureLimits webAdvanced() => const ShareCaptureLimits(
        maxPixels: advancedMaxPixelsWeb,
        maxStripPhysicalPx: advancedMaxStripPhysicalPxWeb,
      );
}
