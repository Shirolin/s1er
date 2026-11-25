import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'share_capture_limits.dart';
import 'share_image_stitch.dart';
import 'share_capture_helpers.dart';

/// Logical scrollable height for a [ScrollController] (extent + viewport).
double measureScrollableLogicalHeight(ScrollController controller) {
  if (!controller.hasClients) return 0;
  final position = controller.position;
  return position.maxScrollExtent + position.viewportDimension;
}

/// Picks capture height: prefer live scroll metrics over a stale estimate.
@visibleForTesting
double effectiveScrollCaptureHeight({
  required double estimatedHeight,
  required double measuredHeight,
}) {
  if (measuredHeight > 0) return measuredHeight;
  return estimatedHeight;
}

/// Returns true when the next slice would repeat the same scroll offset.
@visibleForTesting
bool shouldStopScrollCapture({
  required double actualOffset,
  required double? lastCapturedOffset,
}) {
  return lastCapturedOffset != null &&
      (actualOffset - lastCapturedOffset).abs() < 0.5;
}

/// Planned physical-row slice and covered logical span for one scroll frame.
typedef ScrollSliceCropPlan = ({
  int startPhysicalRow,
  int endPhysicalRow,
  double coveredStartLogical,
  double coveredEndLogical,
});

/// Computes which physical rows of a captured viewport [stripPhysicalHeight]
/// (rendered at [actualOffset]) continue seamlessly from [capturedEndLogical]
/// up to [effectiveHeight]. Returns `null` when no uncaptured rows remain.
@visibleForTesting
ScrollSliceCropPlan? planScrollSliceCrop({
  required double capturedEndLogical,
  required double actualOffset,
  required double effectiveHeight,
  required int stripPhysicalHeight,
  required double pixelRatio,
}) {
  if (stripPhysicalHeight <= 0 || pixelRatio <= 0 || effectiveHeight <= 0) {
    return null;
  }
  final visibleEndLogical = actualOffset + stripPhysicalHeight / pixelRatio;
  final sliceEndLogical =
      visibleEndLogical < effectiveHeight ? visibleEndLogical : effectiveHeight;
  if (sliceEndLogical <= capturedEndLogical) {
    return null;
  }
  final skipLogical = capturedEndLogical - actualOffset;
  final startRow = skipLogical <= 0
      ? 0
      : (skipLogical * pixelRatio).round().clamp(0, stripPhysicalHeight);
  final endRow = ((sliceEndLogical - actualOffset) * pixelRatio)
      .round()
      .clamp(0, stripPhysicalHeight);
  if (endRow <= startRow) {
    return null;
  }
  return (
    startPhysicalRow: startRow,
    endPhysicalRow: endRow,
    coveredStartLogical: actualOffset + startRow / pixelRatio,
    coveredEndLogical: actualOffset + endRow / pixelRatio,
  );
}

/// Captures a [RenderRepaintBoundary] as one or more RGBA strips.
Future<List<ShareRgbaStrip>> captureBoundaryAsStrips(
  RenderRepaintBoundary boundary, {
  required double pixelRatio,
  required bool inFloorChunking,
  ScrollController? scrollController,
  double? totalLogicalHeight,
  ShareCaptureLimits? limits,
}) async {
  if (!inFloorChunking) {
    final strip = await rgbaStripFromBoundary(boundary, pixelRatio);
    if (strip == null) return [];
    return [strip];
  }

  if (scrollController == null || totalLogicalHeight == null) return [];

  return captureBoundaryWithScrollSlices(
    boundary: boundary,
    scrollController: scrollController,
    totalLogicalHeight: totalLogicalHeight,
    pixelRatio: pixelRatio,
    limits: limits,
  );
}

/// Scrolls a viewport [RepaintBoundary] and captures each slice.
Future<List<ShareRgbaStrip>> captureBoundaryWithScrollSlices({
  required RenderRepaintBoundary boundary,
  required ScrollController scrollController,
  required double totalLogicalHeight,
  required double pixelRatio,
  ShareCaptureLimits? limits,
}) async {
  if (totalLogicalHeight <= 0) return [];

  var effectiveHeight = totalLogicalHeight;
  if (scrollController.hasClients) {
    effectiveHeight = effectiveScrollCaptureHeight(
      estimatedHeight: totalLogicalHeight,
      measuredHeight: measureScrollableLogicalHeight(scrollController),
    );
  }
  if (effectiveHeight <= 0) return [];

  final strips = <ShareRgbaStrip>[];
  final intervals = <ScrollCaptureInterval>[];
  var capturedEnd = 0.0;
  double? lastCapturedOffset;
  while (capturedEnd < effectiveHeight - 0.5) {
    scrollController.jumpTo(capturedEnd);
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!scrollController.hasClients) break;
    final actualOffset = scrollController.offset;
    if (shouldStopScrollCapture(
      actualOffset: actualOffset,
      lastCapturedOffset: lastCapturedOffset,
    )) {
      break;
    }
    lastCapturedOffset = actualOffset;
    final strip = await rgbaStripFromBoundary(boundary, pixelRatio);
    if (strip == null) return [];
    final plan = planScrollSliceCrop(
      capturedEndLogical: capturedEnd,
      actualOffset: actualOffset,
      effectiveHeight: effectiveHeight,
      stripPhysicalHeight: strip.height,
      pixelRatio: pixelRatio,
    );
    if (plan == null) break;
    strips.add(
      cropStripPhysicalRows(
        strip,
        startPhysicalRow: plan.startPhysicalRow,
        endPhysicalRow: plan.endPhysicalRow,
      ),
    );
    intervals.add(
      (
        start: plan.coveredStartLogical,
        end: plan.coveredEndLogical,
      ),
    );
    if (plan.coveredEndLogical <= capturedEnd) break;
    capturedEnd = plan.coveredEndLogical;
  }

  if (!scrollCaptureIntervalsCover(
    expectedLogicalHeight: effectiveHeight,
    intervals: intervals,
  )) {
    return [];
  }

  return strips;
}

/// Converts a repaint boundary to a raw RGBA strip.
Future<ShareRgbaStrip?> rgbaStripFromBoundary(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  ui.Image? image;
  try {
    image = await boundary.toImage(pixelRatio: pixelRatio);
    return await _rgbaStripFromImage(image);
  } on Object {
    await SchedulerBinding.instance.endOfFrame;
    image?.dispose();
    image = null;
    try {
      image = await boundary.toImage(pixelRatio: pixelRatio);
      return await _rgbaStripFromImage(image);
    } on Object {
      return null;
    }
  } finally {
    image?.dispose();
  }
}

Future<ShareRgbaStrip?> _rgbaStripFromImage(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
  return ShareRgbaStrip(
    bytes: Uint8List.sublistView(bytes),
    width: image.width,
    height: image.height,
  );
}
