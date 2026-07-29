import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/share_floor_data.dart';
import 'bbcode_parser.dart';
import 'share_capture_policy.dart';

/// Abort capture when this many share images fail to preload.
const int sharePreloadMaxFailures = 3;

/// Max parallel precache/decode operations during share preload.
const int sharePreloadPrecacheConcurrency = 6;

/// Frames of stable scroll height required before offscreen slice capture.
const int shareLayoutStableFramesRequired = 3;

/// Layout-wait loop attempts before hard failure.
const int shareLayoutMaxAttempts = 80;

/// Logical px tolerance when validating scroll-slice coverage.
const double scrollCaptureCoverageTolerancePx = 2.0;

/// Collect preview, full, and avatar URLs for share-card preload.
List<String> collectShareImageUrls(List<ShareFloorData> floors) {
  final urls = <String>{};
  for (final floor in floors) {
    final html = BbcodeParser.parse(floor.post.message);
    urls.addAll(BbcodeParser.extractShareImageUrls(html));
    final avatar = floor.post.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      urls.add(avatar);
    }
  }
  return urls.toList();
}

/// True when preload failures meet the hard-abort threshold.
bool shouldAbortSharePreload({
  required int totalUrls,
  required int failedUrls,
  int maxFailures = sharePreloadMaxFailures,
}) {
  if (totalUrls == 0) return false;
  return failedUrls >= maxFailures;
}

/// Returns true when captured slice height covers [expectedLogicalHeight].
bool scrollCaptureCoverageOk({
  required double expectedLogicalHeight,
  required double capturedLogicalHeight,
  double toleranceLogicalPx = scrollCaptureCoverageTolerancePx,
}) {
  if (expectedLogicalHeight <= 0) return capturedLogicalHeight > 0;
  return capturedLogicalHeight >= expectedLogicalHeight - toleranceLogicalPx;
}

/// Sum of strip heights converted to logical px.
double scrollCaptureLogicalHeightFromStrips(
  Iterable<int> physicalHeights, {
  required double pixelRatio,
}) {
  if (pixelRatio <= 0) return 0;
  return physicalHeights.fold<double>(
    0,
    (sum, height) => sum + height / pixelRatio,
  );
}

/// Updates layout-stability state; returns new stable-frame count.
int advanceLayoutStability({
  required double? lastHeight,
  required double currentHeight,
  required int stableFrames,
  double tolerancePx = 0.5,
}) {
  if (currentHeight <= 0) return 0;
  if (lastHeight != null && (currentHeight - lastHeight).abs() < tolerancePx) {
    return stableFrames + 1;
  }
  return 0;
}

bool isLayoutStabilityReached({
  required int stableFrames,
  int requiredFrames = shareLayoutStableFramesRequired,
}) {
  return stableFrames >= requiredFrames;
}

/// Runs [action] over [items] with at most [concurrency] in flight.
Future<void> forEachConcurrent<T>(
  List<T> items,
  Future<void> Function(T item) action, {
  int concurrency = sharePreloadPrecacheConcurrency,
}) async {
  if (items.isEmpty) return;
  final limit = concurrency.clamp(1, items.length);
  for (var start = 0; start < items.length; start += limit) {
    final end = math.min(start + limit, items.length);
    await Future.wait(
      items.sublist(start, end).map(action),
    );
  }
}

/// Returns scaled dimensions that fit within [maxPixels] (physical px).
({int width, int height}) scaleDimensionsToFitPixels({
  required int width,
  required int height,
  required int maxPixels,
}) {
  final total = width * height;
  if (total <= maxPixels || total <= 0) {
    return (width: width, height: height);
  }
  final scale = math.sqrt(maxPixels / total);
  return (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );
}

/// Notice appended after a scaled advanced export succeeds.
String formatScaledExportNotice(ShareCaptureSizeInfo size) {
  return '已按设备上限缩放导出${formatShareCaptureSizeShort(size)}';
}

/// Whether [element] subtree contains a loading [CircularProgressIndicator].
bool subtreeHasLoadingIndicator(Element? element) {
  if (element == null) return false;
  var found = false;
  void visit(Element node) {
    if (found) return;
    if (node.widget is CircularProgressIndicator) {
      found = true;
      return;
    }
    node.visitChildren(visit);
  }

  visit(element);
  return found;
}
