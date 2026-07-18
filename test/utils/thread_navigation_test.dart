import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/open_scroll_target.dart';
import 'package:s1er/models/reading_record.dart';
import 'package:s1er/models/thread_destination.dart';
import 'package:s1er/models/thread_open_intent.dart';
import 'package:s1er/utils/thread_navigation.dart';

ReadingRecord _record({
  int lastReadPage = 1,
  int totalPages = 1,
  int lastReadFloor = 1,
  int totalReplies = 0,
  int perPage = 40,
}) {
  return ReadingRecord(
    tid: '100',
    subject: '标题',
    author: 'author',
    fid: '4',
    lastReadPage: lastReadPage,
    lastReadFloor: lastReadFloor,
    totalPages: totalPages,
    totalReplies: totalReplies,
    perPage: perPage,
    lastReadAt: 1,
    firstReadAt: 1,
    readCount: 1,
  );
}

void main() {
  group('ThreadRouteCodec', () {
    group('forum list-detail route', () {
      test('encodes a forced page without colliding with forum page', () {
        expect(
          ThreadRouteCodec.encodeForumPath('4', const ThreadPage('100', 3)),
          '/forum/4?tid=100&threadPage=3',
        );
      });

      test('pid takes priority and restores the post intent', () {
        final intent = ThreadRouteCodec.forumIntentFromUri(
          Uri.parse('/forum/4?tid=100&threadPage=3&pid=999'),
        );
        expect(intent?.mode, ThreadOpenMode.post);
        expect(intent?.pid, '999');
      });

      test('resume page hint restores resume intent', () {
        final intent = ThreadRouteCodec.forumIntentFromUri(
          Uri.parse('/forum/4?tid=100&threadPage=3&resume=1'),
        );
        expect(intent?.mode, ThreadOpenMode.resume);
        expect(intent?.page, 3);
      });

      test('missing tid does not create a detail intent', () {
        expect(
          ThreadRouteCodec.forumIntentFromUri(Uri.parse('/forum/4')),
          isNull,
        );
      });
    });

    test('resume round-trip is bare path', () {
      const dest = ResumeThread('100');
      final uri = ThreadRouteCodec.encode(dest);
      expect(uri.toString(), '/thread/100');
      expect(ThreadRouteCodec.decode(uri, tid: '100'), isA<ResumeThread>());
    });

    test('page=1 encodes and decodes as forced page', () {
      const dest = ThreadPage('100', 1);
      final uri = ThreadRouteCodec.encode(dest);
      expect(uri.toString(), '/thread/100?page=1');
      final decoded = ThreadRouteCodec.decode(uri, tid: '100');
      expect(decoded, isA<ThreadPage>());
      expect((decoded as ThreadPage).page, 1);
    });

    test('page=N round-trip', () {
      final uri = ThreadRouteCodec.encode(const ThreadPage('100', 5));
      expect(uri.toString(), '/thread/100?page=5');
      expect(
        (ThreadRouteCodec.decode(uri, tid: '100') as ThreadPage).page,
        5,
      );
    });

    test('pid round-trip', () {
      final uri = ThreadRouteCodec.encode(const ThreadPost('100', '999'));
      expect(uri.toString(), '/thread/100?pid=999');
      expect(
        (ThreadRouteCodec.decode(uri, tid: '100') as ThreadPost).pid,
        '999',
      );
    });

    test('pid wins over page when both present', () {
      final uri = Uri.parse('/thread/100?page=3&pid=999');
      final decoded = ThreadRouteCodec.decode(uri, tid: '100');
      expect(decoded, isA<ThreadPost>());
      expect((decoded as ThreadPost).pid, '999');
    });

    test('page with resume=1 stays resume destination', () {
      final uri = Uri.parse('/thread/100?page=3&resume=1');
      expect(ThreadRouteCodec.decode(uri, tid: '100'), isA<ResumeThread>());
      final intent = ThreadRouteCodec.intentFromUri(uri, tid: '100');
      expect(intent.mode, ThreadOpenMode.resume);
      expect(intent.page, 3);
    });

    test('illegal page falls back to resume', () {
      final uri = Uri.parse('/thread/100?page=abc');
      expect(ThreadRouteCodec.decode(uri, tid: '100'), isA<ResumeThread>());
    });

    test('intentFromUri maps forced page=1', () {
      final intent = ThreadRouteCodec.intentFromUri(
        Uri.parse('/thread/100?page=1'),
        tid: '100',
      );
      expect(intent.mode, ThreadOpenMode.page);
      expect(intent.page, 1);
    });
  });

  group('resolveThreadInitialPage', () {
    test('A2 explicit page takes priority over reading record', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent.page(5),
          record: _record(
            lastReadPage: 3,
            lastReadFloor: 85,
            totalPages: 8,
            totalReplies: 319,
          ),
        ),
        5,
      );
    });

    test('B1 resume unfinished thread at lastReadFloor page', () {
      expect(
        resolveThreadInitialPage(
          intent: null,
          record: _record(
            lastReadPage: 3,
            lastReadFloor: 85,
            totalPages: 8,
            totalReplies: 319,
          ),
        ),
        3,
      );
    });

    test('B2 finished thread opens last page when live matches', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent.resume(liveTotalReplies: 199),
          record: _record(
            lastReadPage: 5,
            lastReadFloor: 200,
            totalPages: 5,
            totalReplies: 199,
          ),
        ),
        5,
      );
    });

    test('B3 finished thread with new replies opens first unread floor page',
        () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent.resume(liveTotalReplies: 279),
          record: _record(
            lastReadPage: 5,
            lastReadFloor: 200,
            totalPages: 5,
            totalReplies: 199,
          ),
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

    test('page=1 forces first page over record resume', () {
      expect(
        resolveThreadInitialPage(
          intent: const ThreadOpenIntent.page(1),
          record: _record(
            lastReadPage: 4,
            lastReadFloor: 140,
            totalPages: 8,
            totalReplies: 319,
          ),
        ),
        1,
      );
    });
  });

  group('floorToPageIndex / resolveResumeScrollTarget', () {
    test('maps absolute floor to page-local index', () {
      expect(
        floorToPageIndex(
          absoluteFloor: 45,
          page: 2,
          perPage: 40,
          postCount: 40,
        ),
        4,
      );
    });

    test('clamps floor below page start to 0', () {
      expect(
        floorToPageIndex(
          absoluteFloor: 1,
          page: 2,
          perPage: 40,
          postCount: 40,
        ),
        0,
      );
    });

    test('clamps floor past page end to last index', () {
      expect(
        floorToPageIndex(
          absoluteFloor: 999,
          page: 2,
          perPage: 40,
          postCount: 10,
        ),
        9,
      );
    });

    test('resume with floor → ScrollToFloor', () {
      final target = resolveResumeScrollTarget(
        record: _record(
          lastReadPage: 2,
          totalPages: 5,
          lastReadFloor: 45,
          totalReplies: 199,
        ),
        loadedPage: 2,
        liveTotalReplies: 199,
      );
      expect(target, isA<ScrollToFloor>());
      expect((target as ScrollToFloor).absoluteFloor, 45);
    });

    test('B3 new replies → ScrollToPageTop on first unread page', () {
      final target = resolveResumeScrollTarget(
        record: _record(
          lastReadPage: 5,
          totalPages: 5,
          lastReadFloor: 200,
          totalReplies: 199,
        ),
        loadedPage: 6,
        liveTotalReplies: 279,
      );
      expect(target, isA<ScrollToPageTop>());
    });

    test('no record → ScrollToPageTop', () {
      expect(
        resolveResumeScrollTarget(
          record: null,
          loadedPage: 1,
          liveTotalReplies: 0,
        ),
        isA<ScrollToPageTop>(),
      );
    });
  });

  group('buildThreadDetailPath', () {
    test('includes page+resume query when target page > 1', () {
      expect(
        buildThreadDetailPath(
          '100',
          record: _record(
            lastReadPage: 3,
            lastReadFloor: 85,
            totalPages: 8,
            totalReplies: 319,
          ),
          liveTotalReplies: 319,
        ),
        '/thread/100?page=3&resume=1',
      );
    });

    test('omits page query for page 1', () {
      expect(
        buildThreadDetailPath('100'),
        '/thread/100',
      );
    });
  });

  group('entry path fixtures', () {
    test('thread_card forced page 1 encodes ?page=1', () {
      expect(
        ThreadRouteCodec.encodePath(const ThreadPage('100', 1)),
        '/thread/100?page=1',
      );
    });

    test('favorites/search resume is bare tid', () {
      expect(
        ThreadRouteCodec.encodePath(const ResumeThread('100')),
        '/thread/100',
      );
    });

    test('messages/quote/user reply use pid destination', () {
      expect(
        ThreadRouteCodec.encodePath(const ThreadPost('100', '55')),
        '/thread/100?pid=55',
      );
    });
  });
}
