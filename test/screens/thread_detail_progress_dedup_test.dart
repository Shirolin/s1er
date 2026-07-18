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
}
