import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/models/thread_open_intent.dart';
import 'package:s1_app/utils/thread_navigation.dart';

ReadingRecord _record({
  int lastReadPage = 1,
  int totalPages = 1,
}) {
  return ReadingRecord(
    tid: '100',
    subject: '标题',
    author: 'author',
    fid: '4',
    lastReadPage: lastReadPage,
    lastReadFloor: 1,
    totalPages: totalPages,
    totalReplies: 0,
    perPage: 40,
    lastReadAt: 1,
    firstReadAt: 1,
    readCount: 1,
  );
}

void main() {
  group('resolveThreadInitialPage', () {
    test('A2 explicit initialPage takes priority over reading record', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent(initialPage: 5),
          record: _record(lastReadPage: 3, totalPages: 8),
        ),
        5,
      );
    });

    test('B1 resume unfinished thread at lastReadPage', () {
      expect(
        resolveThreadInitialPage(
          intent: null,
          record: _record(lastReadPage: 3, totalPages: 8),
        ),
        3,
      );
    });

    test('B2 finished thread opens last page when live matches', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent(liveTotalPages: 5),
          record: _record(lastReadPage: 5, totalPages: 5),
        ),
        5,
      );
    });

    test('B3 finished thread with new pages opens first new page', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent(liveTotalPages: 7),
          record: _record(lastReadPage: 5, totalPages: 5),
        ),
        6,
      );
    });

    test('B4 no record defaults to page 1', () {
      expect(
        resolveThreadInitialPage(intent: null, record: null),
        1,
      );
    });

    test('initialPage 1 does not override record resume', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent(initialPage: 1),
          record: _record(lastReadPage: 4, totalPages: 8),
        ),
        4,
      );
    });
  });

  group('buildThreadDetailPath', () {
    test('includes page query when target page > 1', () {
      expect(
        buildThreadDetailPath(
          '100',
          record: _record(lastReadPage: 3, totalPages: 8),
          liveTotalPages: 8,
        ),
        '/thread/100?page=3',
      );
    });

    test('omits page query for page 1', () {
      expect(
        buildThreadDetailPath('100'),
        '/thread/100',
      );
    });
  });
}
