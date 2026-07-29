import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
import 'package:s1er/utils/share_capture_helpers.dart';

import '../helpers/test_theme.dart';

Post _post({required String message, String? avatar}) {
  return Post.fromJson({
    'pid': '1',
    'message': message,
    'author': 'a',
    'authorid': '1',
    'dbdateline': '1720000000',
    'number': '1',
    if (avatar != null) 'avatar': avatar,
  });
}

void main() {
  group('collectShareImageUrls', () {
    test('collects preview, full, and avatar urls', () {
      final floors = [
        ShareFloorData(
          post: _post(
            message: '[img]https://a/p.jpg[/img][img]https://b/p2.jpg[/img]',
            avatar: 'https://avatar/a.png',
          ),
          displayFloor: 1,
        ),
        ShareFloorData(
          post: _post(message: 'text only'),
          displayFloor: 2,
        ),
      ];

      final urls = collectShareImageUrls(floors);
      expect(urls, contains('https://a/p.jpg'));
      expect(urls, contains('https://b/p2.jpg'));
      expect(urls.any((url) => url.contains('avatar')), isTrue);
    });
  });

  group('shouldAbortSharePreload', () {
    test('aborts at threshold', () {
      expect(
        shouldAbortSharePreload(totalUrls: 10, failedUrls: 2),
        isFalse,
      );
      expect(
        shouldAbortSharePreload(totalUrls: 10, failedUrls: 3),
        isTrue,
      );
    });
  });

  group('scrollCaptureCoverageOk', () {
    test('accepts within tolerance', () {
      expect(
        scrollCaptureCoverageOk(
          expectedLogicalHeight: 1000,
          capturedLogicalHeight: 999,
        ),
        isTrue,
      );
      expect(
        scrollCaptureCoverageOk(
          expectedLogicalHeight: 1000,
          capturedLogicalHeight: 996,
        ),
        isFalse,
      );
    });
  });

  group('layout stability', () {
    test('advanceLayoutStability counts stable frames', () {
      expect(
        advanceLayoutStability(
          lastHeight: 100,
          currentHeight: 100.2,
          stableFrames: 2,
        ),
        3,
      );
      expect(
        advanceLayoutStability(
          lastHeight: 100,
          currentHeight: 110,
          stableFrames: 2,
        ),
        0,
      );
    });

    test('isLayoutStabilityReached', () {
      expect(isLayoutStabilityReached(stableFrames: 2), isFalse);
      expect(isLayoutStabilityReached(stableFrames: 3), isTrue);
    });
  });

  group('scaleDimensionsToFitPixels', () {
    test('scales down when over cap', () {
      final dims = scaleDimensionsToFitPixels(
        width: 900,
        height: 70000,
        maxPixels: 60000000,
      );
      expect(dims.width * dims.height, lessThanOrEqualTo(60000000));
      expect(dims.width, greaterThan(0));
      expect(dims.height, greaterThan(0));
    });
  });

  testWidgets('detects CircularProgressIndicator in subtree', (tester) async {
    late Element root;
    await tester.pumpWidget(
      wrapWithAppTheme(
        MaterialApp(
          home: Builder(
            builder: (context) {
              root = context as Element;
              return const Stack(
                children: [
                  CircularProgressIndicator(),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(subtreeHasLoadingIndicator(root), isTrue);
  });
}
