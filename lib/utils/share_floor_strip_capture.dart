import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'share_capture_policy.dart';
import 'share_image_stitch.dart';

/// Captures a [RenderRepaintBoundary] as one or more RGBA strips.
Future<List<ShareRgbaStrip>> captureBoundaryAsStrips(
  RenderRepaintBoundary boundary, {
  required double pixelRatio,
  required bool inFloorChunking,
  ScrollController? scrollController,
  double? totalLogicalHeight,
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
  );
}

/// Scrolls a viewport [RepaintBoundary] and captures each slice.
Future<List<ShareRgbaStrip>> captureBoundaryWithScrollSlices({
  required RenderRepaintBoundary boundary,
  required ScrollController scrollController,
  required double totalLogicalHeight,
  required double pixelRatio,
}) async {
  if (totalLogicalHeight <= 0) return [];

  final sliceLogicalHeight =
      shareInFloorChunkLogicalSliceHeight(pixelRatio).toDouble();
  final strips = <ShareRgbaStrip>[];
  var y = 0.0;
  while (y < totalLogicalHeight) {
    final remaining = totalLogicalHeight - y;
    final sliceHeight =
        remaining < sliceLogicalHeight ? remaining : sliceLogicalHeight;
    scrollController.jumpTo(y);
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    final strip = await rgbaStripFromBoundary(boundary, pixelRatio);
    if (strip == null) return [];
    strips.add(strip);
    y += sliceHeight;
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
    bytes: Uint8List.fromList(bytes),
    width: image.width,
    height: image.height,
  );
}
