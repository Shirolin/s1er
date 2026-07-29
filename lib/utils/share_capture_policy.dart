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
  return shareCaptureSizeFromLogical(
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    pixelRatio: pixelRatio,
    maxPixels: 0,
  ).totalPixels;
}

/// Physical export dimensions for user-facing / debug messages.
class ShareCaptureSizeInfo {
  const ShareCaptureSizeInfo({
    required this.physicalWidth,
    required this.physicalHeight,
    required this.maxPixels,
  });

  final int physicalWidth;
  final int physicalHeight;
  final int maxPixels;

  int get totalPixels => physicalWidth * physicalHeight;

  @override
  String toString() => formatShareCaptureSizeDetail(this);
}

ShareCaptureSizeInfo shareCaptureSizeFromLogical({
  required double logicalWidth,
  required double logicalHeight,
  required double pixelRatio,
  required int maxPixels,
}) {
  final w = (logicalWidth * pixelRatio).round().clamp(1, 1 << 30);
  final h = (logicalHeight * pixelRatio).round().clamp(1, 1 << 30);
  return ShareCaptureSizeInfo(
    physicalWidth: w,
    physicalHeight: h,
    maxPixels: maxPixels,
  );
}

ShareCaptureSizeInfo shareCaptureSizeFromPhysical({
  required int physicalWidth,
  required int physicalHeight,
  required int maxPixels,
}) {
  return ShareCaptureSizeInfo(
    physicalWidth: physicalWidth,
    physicalHeight: physicalHeight,
    maxPixels: maxPixels,
  );
}

String _formatMegapixels(int pixels) {
  final mp = pixels / 1000000;
  if (mp >= 100) return mp.round().toString();
  return mp.toStringAsFixed(1);
}

/// Full size detail for cap / failure toasts.
String formatShareCaptureSizeDetail(ShareCaptureSizeInfo size) {
  final capSuffix =
      size.maxPixels > 0 ? '，上限 ${_formatMegapixels(size.maxPixels)}M 像素' : '';
  return '约 ${size.physicalWidth}×${size.physicalHeight} px'
      '（${_formatMegapixels(size.totalPixels)}M 像素$capSuffix）';
}

/// Short size hint appended to generic capture failures.
String formatShareCaptureSizeShort(ShareCaptureSizeInfo size) {
  return '（约 ${size.physicalWidth}×${size.physicalHeight} px）';
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
