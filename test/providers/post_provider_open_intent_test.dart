import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/open_scroll_target.dart';
import 'package:s1er/models/reading_record.dart';
import 'package:s1er/models/thread_open_intent.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/reading_history_provider.dart';
import 'package:s1er/providers/thread_open_intent_provider.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/services/http_client.dart';

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
      clearRateLogSessionCacheForTest();
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
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

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
              totalReplies: 319,
              perPage: 40,
              lastReadAt: 1,
              firstReadAt: 1,
              readCount: 1,
            ),
          ),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

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
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);
      // adapter replies=159 → totalPages = ceil(160/40)=4
      final state = await container.read(postProvider('100').future);

      expect(state.currentPage, 3);
      expect(state.openScrollTarget, isA<ScrollToFloor>());
      expect(
        (state.openScrollTarget as ScrollToFloor).absoluteFloor,
        81,
      );
      expect(adapter.requestedPages, contains(3));
    });

    test('marks rate pids but does not fetch on page load', () async {
      adapter.commentCount = {'1': 2};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      await pumpEventQueue();

      final notifier = container.read(threadRateLogsProvider('100').notifier);
      expect(notifier.isMarked('1'), isTrue);
      expect(adapter.rateLogRequests, isEmpty);
      expect(adapter.pageHtmlRequests, isEmpty);
    });

    test('marks commentcount keys with zero value', () async {
      adapter.commentCount = {'1': 0};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      await pumpEventQueue();

      expect(
        container.read(threadRateLogsProvider('100').notifier).isMarked('1'),
        isTrue,
      );
      expect(adapter.rateLogRequests, isEmpty);
    });

    test('v1 response without commentcount triggers page HTML fallback',
        () async {
      adapter.forceLegacyVersion = true;
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        container.read(threadRateLogsProvider('100').notifier).isMarked('1'),
        isFalse,
      );
      expect(adapter.rateLogRequests, isEmpty);
      expect(adapter.pageHtmlRequests, hasLength(1));
    });

    test('v4 503 downgrade falls back to page HTML for rate logs', () async {
      adapter.commentCount = {'1': 2};
      adapter.pageHtml = '''
<div id="ratelog_1"><ul>
<li><div class="flex-2"><a>参与人数 <span>1</span></a></div>
<div class="flex-2">战斗力 <i>+2</i></div><div class="flex-3">理由</div></li>
<li><div class="flex-2"><a href="space-uid-1.html">userA</a></div>
<div class="flex-2">+ 2</div><div class="flex-3">good</div></li>
</ul></div>
''';
      adapter.failV4With503 = true;
      adapter.forceLegacyVersion = true;
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      await pumpEventQueue();
      await pumpEventQueue();

      // 走整页 HTML 兜底，而不是补发 v4
      expect(adapter.pageHtmlRequests, hasLength(1));
      expect(adapter.v4RateRequests, hasLength(1)); // 只有最初失败的那次
      expect(adapter.rateLogRequests, isEmpty);
      final log = container.read(rateLogProvider(('100', '1')));
      expect(log, isNotNull);
      expect(log!.totalScore, 2);
    });

    test('normal v4 page never requests page HTML', () async {
      adapter.commentCount = {'1': 2};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      await pumpEventQueue();

      expect(adapter.pageHtmlRequests, isEmpty);
      expect(
        container.read(threadRateLogsProvider('100').notifier).isMarked('1'),
        isTrue,
      );
    });

    test('ensureRateLog requests only the given pid', () async {
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      await container
          .read(threadRateLogsProvider('100').notifier)
          .ensureRateLog('1');

      expect(adapter.rateLogRequests, hasLength(1));
      final uri = adapter.rateLogRequests.single;
      expect(uri.queryParameters['action'], 'viewratings');
      expect(uri.queryParameters['pid'], '1');
      expect(uri.queryParameters['inajax'], '1');
      expect(uri.queryParameters['mobile'], 'no');
      expect(adapter.pageHtmlRequests, isEmpty);
    });

    test('reuses the current pid rate log cache', () async {
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      final notifier = container.read(threadRateLogsProvider('100').notifier);
      await notifier.ensureRateLog('1');
      await notifier.ensureRateLog('1');

      expect(adapter.rateLogRequests, hasLength(1));
    });

    test('rate log merge does not mutate postProvider state', () async {
      adapter.commentCount = {'1': 2};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );

      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      final initial = await container.read(postProvider('100').future);
      final postsBefore = initial.posts;

      await container
          .read(threadRateLogsProvider('100').notifier)
          .ensureRateLog('1');

      final after = container.read(postProvider('100')).asData!.value;
      expect(identical(after.posts, postsBefore), isTrue);
      expect(
        container.read(threadRateLogsProvider('100')),
        isNotEmpty,
      );
    });
  });

  group('PostNotifier.restoreToFloor', () {
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
          readingRecordProvider('100').overrideWithValue(null),
          ...extraOverrides,
        ],
      );
      return c;
    }

    setUp(() {
      adapter = _ThreadDetailAdapter();
      clearRateLogSessionCacheForTest();
    });

    tearDown(() {
      container.dispose();
    });

    test('same-page restore returns true and sets ScrollToFloor', () async {
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.page(2),
          ),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      final ok =
          await container.read(postProvider('100').notifier).restoreToFloor(
                page: 2,
                absoluteFloor: 45,
              );

      expect(ok, isTrue);
      final state = container.read(postProvider('100')).asData!.value;
      expect(state.currentPage, 2);
      expect(state.openScrollTarget, isA<ScrollToFloor>());
      expect((state.openScrollTarget! as ScrollToFloor).absoluteFloor, 45);
      expect(adapter.requestedPages, [2]);
    });

    test('cross-page restore success returns true', () async {
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.page(2),
          ),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      final ok =
          await container.read(postProvider('100').notifier).restoreToFloor(
                page: 1,
                absoluteFloor: 3,
              );

      expect(ok, isTrue);
      final state = container.read(postProvider('100')).asData!.value;
      expect(state.currentPage, 1);
      expect(state.openScrollTarget, isA<ScrollToFloor>());
      expect(adapter.requestedPages, [2, 1]);
    });

    test('cross-page restore failure returns false and keeps previous page',
        () async {
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent.page(2),
          ),
        ],
      );
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      adapter.failPages.add(1);

      final ok =
          await container.read(postProvider('100').notifier).restoreToFloor(
                page: 1,
                absoluteFloor: 3,
              );

      expect(ok, isFalse);
      final state = container.read(postProvider('100')).asData!.value;
      expect(state.currentPage, 2);
      expect(container.read(postProvider('100')).hasError, isFalse);
    });
  });

  group('PostNotifier.goToPage', () {
    late _ThreadDetailAdapter adapter;
    late ProviderContainer container;

    ProviderContainer buildContainer() {
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(c, dio),
          ),
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      return c;
    }

    setUp(() {
      adapter = _ThreadDetailAdapter();
      clearRateLogSessionCacheForTest();
    });

    tearDown(() {
      container.dispose();
    });

    test('success advances to requested page', () async {
      container = buildContainer();
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      final ok = await container.read(postProvider('100').notifier).goToPage(3);

      expect(ok, isTrue);
      final state = container.read(postProvider('100')).asData!.value;
      expect(state.currentPage, 3);
      expect(state.openScrollTarget, isA<ScrollToPageTop>());
    });

    test('failure returns false and keeps previous page without error state',
        () async {
      container = buildContainer();
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      adapter.failPages.add(2);

      final ok = await container.read(postProvider('100').notifier).goToPage(2);

      // 失败必须显式返回 false：调用方据此停住路由与页码推进。
      expect(ok, isFalse);
      final async = container.read(postProvider('100'));
      expect(async.hasError, isFalse);
      expect(async.asData!.value.currentPage, 1);
    });
  });
}

class _ThreadDetailAdapter implements HttpClientAdapter {
  final requestedPages = <int>[];
  final locateRequests = <String>[];
  final locatePageForPid = <String, int>{};
  final rateLogRequests = <Uri>[];
  final pageHtmlRequests = <Uri>[];
  final v4RateRequests = <Uri>[];
  final failPages = <int>{};
  Map<String, int>? commentCount;
  bool failV4With503 = false;
  bool forceLegacyVersion = false;
  String pageHtml = '<html></html>';
  String rateLogHtml = '''
<table class="list">
<thead><tr><td>积分</td><td>用户名</td><td>时间</td><td>理由</td></tr></thead>
<tr>
<td>战斗力 +2 鹅</td>
<td><a href="space-uid-1.html">userA</a></td>
<td>2026-8-12 20:27</td>
<td>good</td>
</tr>
</table>
''';
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
      if (failPages.contains(page)) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 500),
          message: 'simulated page $page failure',
        );
      }
      final pid = omitPidFromPostlist ? '1' : (_lastLocatedPid ?? '1');
      final requestedVersion = uri.queryParameters['version'];
      if (requestedVersion == '4') v4RateRequests.add(uri);
      if (requestedVersion == '4' && failV4With503) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 503),
          message: 'simulated v4 503',
        );
      }
      // 响应体里的 Version：模拟「服务端降级返回 v1」
      final version = forceLegacyVersion ? '1' : requestedVersion;
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
      // 模拟真实 v1 响应：没有 commentcount
      if (commentCount != null && version == '4') {
        variables['commentcount'] = commentCount;
      }
      return ResponseBody.fromString(
        jsonEncode({
          'Version': version ?? '4',
          'Variables': variables,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (uri.query.contains('action=viewratings')) {
      rateLogRequests.add(uri);
      return ResponseBody.fromString(rateLogHtml, 200);
    }

    if (uri.query.contains('mod=viewthread')) {
      pageHtmlRequests.add(uri);
      return ResponseBody.fromString(pageHtml, 200);
    }
    return ResponseBody.fromString('{}', 200);
  }
}
