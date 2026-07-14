import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/open_scroll_target.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/models/thread_open_intent.dart';
import 'package:s1_app/providers/post_provider.dart';
import 'package:s1_app/providers/reading_history_provider.dart';
import 'package:s1_app/providers/thread_open_intent_provider.dart';
import 'package:s1_app/providers/thread_rate_logs_provider.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('PostNotifier open intent', () {
    late _ThreadDetailAdapter adapter;
    late ProviderContainer container;

    ProviderContainer buildContainer({
      // ignore: strict_raw_type
      List extraOverrides = const [],
    }) {
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(c, dio),
          ),
          ...extraOverrides,
        ],
      );
      return c;
    }

    setUp(() {
      adapter = _ThreadDetailAdapter();
    });

    tearDown(() {
      container.dispose();
    });

    test('page mode loads explicit page on first request', () async {
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.page(5),
          ),
        ],
      );

      final state = await container.read(postProvider('100').future);

      expect(state.currentPage, 5);
      expect(adapter.requestedPages, [5]);
      expect(adapter.requestedPages, isNot(contains(1)));
      expect(state.openScrollTarget, isA<ScrollToPageTop>());
    });

    test('page=1 forces first page over resume record', () async {
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.page(1),
          ),
          readingRecordProvider('100').overrideWithValue(
            ReadingRecord(
              tid: '100',
              subject: 't',
              author: 'a',
              fid: '4',
              lastReadPage: 4,
              lastReadFloor: 120,
              totalPages: 8,
              totalReplies: 0,
              perPage: 40,
              lastReadAt: 1,
              firstReadAt: 1,
              readCount: 1,
            ),
          ),
        ],
      );

      final state = await container.read(postProvider('100').future);
      expect(state.currentPage, 1);
      expect(adapter.requestedPages, [1]);
      expect(state.openScrollTarget, isA<ScrollToPageTop>());
    });

    test('post mode locates page before loading detail', () async {
      adapter.locatePageForPid['999'] = 187;
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.post('999'),
          ),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      final state = await container.read(postProvider('100').future);

      expect(state.currentPage, 187);
      expect(adapter.locateRequests, contains('100:999'));
      expect(adapter.requestedPages, [187]);
      expect(adapter.requestedPages, isNot(contains(1)));
      expect(state.openScrollTarget, isA<ScrollToPid>());
      expect((state.openScrollTarget as ScrollToPid).pid, '999');
      expect(state.locateError, isNull);
    });

    test('post mode sets locateError when pid missing on page', () async {
      adapter.locatePageForPid['999'] = 2;
      adapter.omitPidFromPostlist = true;
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.post('999'),
          ),
        ],
      );

      final state = await container.read(postProvider('100').future);
      expect(state.locateError, '未找到目标楼层');
      expect(state.openScrollTarget, isA<ScrollToPageTop>());
    });

    test('reading record resume loads lastReadPage with ScrollToFloor',
        () async {
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(
            ReadingRecord(
              tid: '100',
              subject: 't',
              author: 'a',
              fid: '4',
              lastReadPage: 3,
              lastReadFloor: 85,
              totalPages: 8,
              totalReplies: 0,
              perPage: 40,
              lastReadAt: 1,
              firstReadAt: 1,
              readCount: 1,
            ),
          ),
        ],
      );

      final state = await container.read(postProvider('100').future);

      expect(state.currentPage, 3);
      expect(adapter.requestedPages, [3]);
      expect(state.openScrollTarget, isA<ScrollToFloor>());
      expect((state.openScrollTarget as ScrollToFloor).absoluteFloor, 85);
    });

    test('B3 finished with new pages opens new page at top', () async {
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(
            ReadingRecord(
              tid: '100',
              subject: 't',
              author: 'a',
              fid: '4',
              lastReadPage: 2,
              lastReadFloor: 80,
              totalPages: 2,
              totalReplies: 79,
              perPage: 40,
              lastReadAt: 1,
              firstReadAt: 1,
              readCount: 1,
            ),
          ),
        ],
      );
      // adapter replies=159 → totalPages = ceil(160/40)=4
      final state = await container.read(postProvider('100').future);

      expect(state.currentPage, 3);
      expect(state.openScrollTarget, isA<ScrollToPageTop>());
      expect(adapter.requestedPages, contains(3));
    });

    test('fetches rate logs when commentcount is zero', () async {
      adapter.commentCount = {'1': 0};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);

      expect(adapter.rateLogRequests, isNotEmpty);
    });

    test('fetches rate logs when commentcount is missing', () async {
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);

      expect(adapter.rateLogRequests, isNotEmpty);
    });

    test('auto-fetches rate logs on page load when commentcount > 0', () async {
      adapter.commentCount = {'1': 2};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);

      expect(adapter.rateLogRequests, isNotEmpty);
    });

    test('rate log merge does not mutate postProvider state', () async {
      adapter.commentCount = {'1': 2};
      adapter.rateLogHtml = '''
<div id="ratelog_1">
  <ul class="post_box cl">
    <li class="flex-box mli p0">
      <div class="flex-2"><a> 参与人数 <span class="xi1">1</span></a></div>
      <div class="flex-2">战斗力 <i><span class="xi1">+2</span></i></div>
      <div class="flex-3">理由</div>
    </li>
    <li class="flex-box mli p0">
      <div class="flex-2"><a href="home.php?mod=space&uid=1">userA</a></div>
      <div class="flex-2 xi1"> + 2</div>
      <div class="flex-3">good</div>
    </li>
  </ul>
</div>
''';
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );

      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      final initial = await container.read(postProvider('100').future);
      final postsBefore = initial.posts;

      expect(adapter.rateLogRequests, isNotEmpty);

      final after = container.read(postProvider('100')).asData!.value;
      expect(identical(after.posts, postsBefore), isTrue);
      expect(adapter.rateLogRequests, isNotEmpty);
      expect(
        container.read(threadRateLogsProvider('100')),
        isNotEmpty,
      );
    });
  });
}

class _ThreadDetailAdapter implements HttpClientAdapter {
  final requestedPages = <int>[];
  final locateRequests = <String>[];
  final locatePageForPid = <String, int>{};
  final rateLogRequests = <Uri>[];
  Map<String, int>? commentCount;
  String rateLogHtml = '<html></html>';
  bool omitPidFromPostlist = false;
  String? _lastLocatedPid;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;

    if (uri.queryParameters['goto'] == 'findpost') {
      final ptid = uri.queryParameters['ptid'] ?? '';
      final pid = uri.queryParameters['pid'] ?? '';
      locateRequests.add('$ptid:$pid');
      _lastLocatedPid = pid;
      final page = locatePageForPid[pid] ?? 1;
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://stage1st.com/2b/forum.php?mod=viewthread&tid=$ptid&page=$page',
          ],
        },
      );
    }

    if (uri.query.contains('module=viewthread')) {
      final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
      requestedPages.add(page);
      final pid = omitPidFromPostlist
          ? '1'
          : (_lastLocatedPid ?? '1');
      final variables = <String, dynamic>{
        'ppp': '40',
        'thread': {
          'subject': 'Test Thread',
          'fid': '4',
          'replies': '159',
          'allowreply': '1',
        },
        'postlist': [
          {
            'pid': pid,
            'author': 'user',
            'authorid': '1',
            'message': 'body',
            'dateline': '1700000000',
            'floor': '1',
          },
        ],
      };
      if (commentCount != null) {
        variables['commentcount'] = commentCount;
      }
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': variables,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (uri.query.contains('mod=viewthread')) {
      rateLogRequests.add(uri);
      return ResponseBody.fromString(rateLogHtml, 200);
    }

    return ResponseBody.fromString('{}', 200);
  }
}
