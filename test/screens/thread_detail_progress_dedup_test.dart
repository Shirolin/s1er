import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/screens/thread_detail_screen.dart';

void main() {
  test('first visit always writes progress', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: false,
        lastRecordedPage: null,
        currentPage: 1,
      ),
      isTrue,
    );
  });

  test('same page after initial visit skips write', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: true,
        lastRecordedPage: 2,
        currentPage: 2,
      ),
      isFalse,
    );
  });

  test('page change after initial visit writes progress', () {
    expect(
      shouldWriteReadingProgressUpdate(
        hasRecordedInitialVisit: true,
        lastRecordedPage: 2,
        currentPage: 3,
      ),
      isTrue,
    );
  });
}
