import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../config/constants.dart';
import 'share_capture_limits.dart';

/// Whether a capture should use per-floor chunking + stitch instead of one shot.
bool shouldUseChunkedShareCapture({
  required int floorCount,
  required int estimatedCapturePixels,
  int chunkThresholdPixels = S1Constants.shareCaptureChunkThresholdPixels,
}) {
  if (floorCount <= 0) return false;
  if (floorCount > 1) return true;
  return estimatedCapturePixels >= chunkThresholdPixels;
}

/// Whether the estimated capture exceeds the hard pixel budget.
bool exceedsShareCaptureHardCap({
  required int estimatedCapturePixels,
  bool advanced = false,
  int? maxPixels,
  ShareCaptureLimits? limits,
}) {
  final cap = maxPixels ??
      limits?.maxPixels ??
      (advanced
          ? S1Constants.shareCaptureMaxPixelsAdvanced
          : S1Constants.shareCaptureMaxPixels);
  return estimatedCapturePixels > cap;
}

/// Export pixel count from a laid-out logical size and capture [pixelRatio].
int estimateShareCapturePixels({
  required double logicalWidth,
  required double logicalHeight,
  required double pixelRatio,
}) {
  final w = (logicalWidth * pixelRatio).round().clamp(1, 1 << 30);
  final h = (logicalHeight * pixelRatio).round().clamp(1, 1 << 30);
  return w * h;
}

/// Soft-cap check before adding another floor to the selection.
bool canAddShareFloor({
  required int currentCount,
  int maxFloors = S1Constants.shareMaxSelectedFloors,
}) {
  return currentCount < maxFloors;
}

int _maxStripPhysicalPx(ShareCaptureLimits? limits) {
  return limits?.maxStripPhysicalPx ??
      S1Constants.shareInFloorChunkMaxStripPhysicalPx;
}

/// Logical slice height for in-floor scroll-viewport capture.
int shareInFloorChunkLogicalSliceHeight(
  double pixelRatio, {
  ShareCaptureLimits? limits,
}) {
  if (pixelRatio <= 0) return 1;
  return math.max(
    1,
    (_maxStripPhysicalPx(limits) / pixelRatio).floor(),
  );
}

/// Whether a single floor strip should be split with in-floor slicing.
bool shouldUseInFloorChunking({
  required bool advancedEnabled,
  required double floorLogicalHeight,
  required double pixelRatio,
  ShareCaptureLimits? limits,
}) {
  if (!advancedEnabled || floorLogicalHeight <= 0 || pixelRatio <= 0) {
    return false;
  }
  final floorPhysicalHeight = floorLogicalHeight * pixelRatio;
  return floorPhysicalHeight > _maxStripPhysicalPx(limits);
}

/// Number of in-floor rect slices for a laid-out floor height.
@visibleForTesting
int inFloorChunkSliceCount({
  required double floorLogicalHeight,
  required double pixelRatio,
  ShareCaptureLimits? limits,
}) {
  if (floorLogicalHeight <= 0) return 0;
  final sliceHeight = shareInFloorChunkLogicalSliceHeight(
    pixelRatio,
    limits: limits,
  );
  return (floorLogicalHeight / sliceHeight).ceil();
}
