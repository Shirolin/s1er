import '../config/constants.dart';

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
  int maxPixels = S1Constants.shareCaptureMaxPixels,
}) {
  return estimatedCapturePixels > maxPixels;
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
