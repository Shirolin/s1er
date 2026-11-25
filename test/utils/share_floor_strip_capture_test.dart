import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/share_capture_helpers.dart';
import 'package:s1er/utils/share_capture_policy.dart';
import 'package:s1er/utils/share_floor_strip_capture.dart';
import 'package:s1er/utils/share_image_stitch.dart';

void main() {
  group('scroll capture helpers', () {
    test('effectiveScrollCaptureHeight prefers measured height', () {
      expect(
        effectiveScrollCaptureHeight(
          estimatedHeight: 5000,
          measuredHeight: 4200,
        ),
        4200,
      );
      expect(
        effectiveScrollCaptureHeight(
          estimatedHeight: 5000,
          measuredHeight: 0,
        ),
        5000,
      );
    });

    test('shouldStopScrollCapture detects repeated offset', () {
      expect(
        shouldStopScrollCapture(actualOffset: 100, lastCapturedOffset: 100),
        isTrue,
      );
      expect(
        shouldStopScrollCapture(actualOffset: 100, lastCapturedOffset: 50),
        isFalse,
      );
    });

    test('scrollCaptureLogicalHeightFromStrips sums physical heights', () {
      final logical = scrollCaptureLogicalHeightFromStrips(
        [300, 150],
        pixelRatio: 1.5,
      );
      expect(logical, 300);
    });
  });

  group('inFloorChunkSliceCount', () {
    test('returns zero for non-positive height', () {
      expect(
        inFloorChunkSliceCount(floorLogicalHeight: 0, pixelRatio: 1.5),
        0,
      );
      expect(
        inFloorChunkSliceCount(floorLogicalHeight: -10, pixelRatio: 1.5),
        0,
      );
    });

    test('ceil-divides floor height by slice height', () {
      final sliceHeight = shareInFloorChunkLogicalSliceHeight(1.5);
      expect(
        inFloorChunkSliceCount(
          floorLogicalHeight: sliceHeight.toDouble(),
          pixelRatio: 1.5,
        ),
        1,
      );
      expect(
        inFloorChunkSliceCount(
          floorLogicalHeight: sliceHeight + 1.0,
          pixelRatio: 1.5,
        ),
        2,
      );
    });
  });

  group('planScrollSliceCrop', () {
    test('captures full first slice when shorter than total height', () {
      final plan = planScrollSliceCrop(
        capturedEndLogical: 0,
        actualOffset: 0,
        effectiveHeight: 4000,
        stripPhysicalHeight: 4095, // 2730 * 1.5
        pixelRatio: 1.5,
      );
      expect(plan, isNotNull);
      expect(plan!.startPhysicalRow, 0);
      expect(plan.endPhysicalRow, 4095);
      expect(plan.coveredStartLogical, 0);
      expect(plan.coveredEndLogical, 2730);
    });

    test('skips clamped overlap and preserves bottom rows on final slice', () {
      // H = 4000, V = 2730, pixelRatio = 1.5.
      // jumpTo(2730) clamps to maxScrollExtent = 4000 - 2730 = 1270.
      // Overlapping top [1270, 2730) = 1460 logical = 2190 physical rows.
      // Remaining bottom [2730, 4000) = 1270 logical = 1905 physical rows.
      final plan = planScrollSliceCrop(
        capturedEndLogical: 2730,
        actualOffset: 1270,
        effectiveHeight: 4000,
        stripPhysicalHeight: 4095,
        pixelRatio: 1.5,
      );
      expect(plan, isNotNull);
      expect(plan!.startPhysicalRow, 2190);
      expect(plan.endPhysicalRow, 4095);
      expect(plan.coveredStartLogical, 2730);
      expect(plan.coveredEndLogical, 4000);
    });

    test('caps single slice at effectiveHeight when content fits in viewport',
        () {
      final plan = planScrollSliceCrop(
        capturedEndLogical: 0,
        actualOffset: 0,
        effectiveHeight: 1200,
        stripPhysicalHeight: 4095,
        pixelRatio: 1.5,
      );
      expect(plan, isNotNull);
      expect(plan!.startPhysicalRow, 0);
      expect(plan.endPhysicalRow, 1800);
      expect(plan.coveredStartLogical, 0);
      expect(plan.coveredEndLogical, 1200);
    });

    test('returns null when nothing uncaptured remains', () {
      final plan = planScrollSliceCrop(
        capturedEndLogical: 4000,
        actualOffset: 1270,
        effectiveHeight: 4000,
        stripPhysicalHeight: 4095,
        pixelRatio: 1.5,
      );
      expect(plan, isNull);
    });
  });

  testWidgets(
      'captureBoundaryWithScrollSlices preserves bottom band when final jump clamps',
      (tester) async {
    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    const bands = <(double height, Color color)>[
      (50, Color(0xFFFF0000)),
      (50, Color(0xFF00FF00)),
      (50, Color(0xFF0000FF)),
      (50, Color(0xFFFFFF00)),
      (40, Color(0xFFFF00FF)),
    ];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 40,
              height: 100,
              child: SingleChildScrollView(
                controller: controller,
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final band in bands)
                      SizedBox(
                        width: 40,
                        height: band.$1,
                        child: ColoredBox(color: band.$2),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    const pixelRatio = 1.5;

    var completed = false;
    late List<ShareRgbaStrip> strips;
    unawaited(
      captureBoundaryWithScrollSlices(
        boundary: boundary,
        scrollController: controller,
        totalLogicalHeight: 240,
        pixelRatio: pixelRatio,
      ).then((value) {
        strips = value;
        completed = true;
      }),
    );

    for (var i = 0; i < 200 && !completed; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }

    expect(completed, isTrue);
    expect(strips.length, 3);

    final stitched = stitchRgbaVertically(strips);
    expect(stitched.width, 60);
    expect(stitched.height, 360);

    (int r, int g, int b, int a) pixelAt(int x, int y) {
      final idx = (y * stitched.width + x) * 4;
      return (
        stitched.bytes[idx],
        stitched.bytes[idx + 1],
        stitched.bytes[idx + 2],
        stitched.bytes[idx + 3],
      );
    }

    // Center physical y for each band: 25*1.5=37, 75*1.5=112, 125*1.5=187,
    // 175*1.5=262, and the bottom-most band 220*1.5=330.
    expect(pixelAt(30, 37), (255, 0, 0, 255));
    expect(pixelAt(30, 112), (0, 255, 0, 255));
    expect(pixelAt(30, 187), (0, 0, 255, 255));
    expect(pixelAt(30, 262), (255, 255, 0, 255));
    expect(pixelAt(30, 330), (255, 0, 255, 255));
  });
}
