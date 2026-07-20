import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/screens/thread_detail_screen.dart';

void main() {
  test('first visit always writes progress', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: false,
        lastRecordedPage: null,
        lastRecordedFloorInPage: null,
        currentPage: 1,
        currentFloorInPage: 1,
      ),
      isTrue,
    );
  });

  test('same page and floor after initial visit skips write', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: true,
        lastRecordedPage: 2,
        lastRecordedFloorInPage: 5,
        currentPage: 2,
        currentFloorInPage: 5,
      ),
      isFalse,
    );
  });

  test('page change after initial visit writes progress', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: true,
        lastRecordedPage: 2,
        lastRecordedFloorInPage: 5,
        currentPage: 3,
        currentFloorInPage: 1,
      ),
      isTrue,
    );
  });

  test('floor change on same page writes progress', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: true,
        lastRecordedPage: 2,
        lastRecordedFloorInPage: 5,
        currentPage: 2,
        currentFloorInPage: 12,
      ),
      isTrue,
    );
  });

  group('resolveFloorInPageForProgress', () {
    test('uses leading floor while not at page bottom', () {
      expect(
        resolveFloorInPageForProgress(
          leadingIndex: 2,
          postCount: 5,
          atPageBottom: false,
        ),
        3,
      );
    });

    test('uses last floor when scrolled to page bottom', () {
      expect(
        resolveFloorInPageForProgress(
          leadingIndex: 2,
          postCount: 5,
          atPageBottom: true,
        ),
        5,
      );
    });

    test('clamps leading index to post count', () {
      expect(
        resolveFloorInPageForProgress(
          leadingIndex: 99,
          postCount: 5,
          atPageBottom: false,
        ),
        5,
      );
    });

    test('empty page falls back to floor 1', () {
      expect(
        resolveFloorInPageForProgress(
          leadingIndex: 0,
          postCount: 0,
          atPageBottom: true,
        ),
        1,
      );
    });

    test('does not regress below minFloorInPage', () {
      expect(
        resolveFloorInPageForProgress(
          leadingIndex: 1,
          postCount: 5,
          atPageBottom: false,
          minFloorInPage: 5,
        ),
        5,
      );
    });
  });
}
