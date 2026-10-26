import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/reading_history_provider.dart';
import 'package:s1er/providers/thread_open_intent_provider.dart';
import 'package:s1er/services/http_client.dart';

/// v4 看帖接口在论坛升级后对个别页面稳定返回 Discuz System Error (503)，
/// 同页 version=1 正常。这里锁定降级行为与重试次数。
void main() {
  group('getThreadDetail version fallback', () {
    late _ViewthreadAdapter adapter;
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
          threadOpenIntentProvider('100').overrideWithValue(null),
        ],
      );
      return c;
    }

    setUp(() {
      adapter = _ViewthreadAdapter();
    });

    tearDown(() {
      container.dispose();
    });

    test('v4 503 falls back to v1 once and loads posts', () async {
      adapter.unstablePages.add(67);
      container = buildContainer();
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      final state = await container.read(postProvider('100').future);

      expect(state.posts, hasLength(1));
      expect(state.currentPage, 1);
      expect(adapter.requestedVersions, ['4']);
    });

    test('page-level fallback hits v1 exactly once', () async {
      adapter.unstablePages.add(2);
      container = buildContainer();
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      adapter.requests.clear();

      final ok = await container.read(postProvider('100').notifier).goToPage(2);

      expect(ok, isTrue);
      expect(
        adapter.requests.where((r) => r.page == 2).map((r) => r.version),
        ['4', '1'],
        reason: '503 只降一级重试，不能无限尝试多个版本',
      );
      final state = container.read(postProvider('100')).asData!.value;
      expect(state.currentPage, 2);
      expect(state.posts, hasLength(1));
    });

    test('both versions failing propagates without extra requests', () async {
      adapter.unstablePages.add(2);
      adapter.brokenInV1.add(2);
      container = buildContainer();
      final sub = container.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      await container.read(postProvider('100').future);
      adapter.requests.clear();

      final ok = await container.read(postProvider('100').notifier).goToPage(2);

      expect(ok, isFalse);
      expect(
        adapter.requests.where((r) => r.page == 2),
        hasLength(2),
        reason: 'v4 + v1 各一次即停，不再继续重试',
      );
    });
  });

  group('closed thread', () {
    test('closed=1 disables reply even without allowreply', () async {
      final adapter = _ViewthreadAdapter()..threadClosed = true;
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith((ref) => S1HttpClient.test(c, dio)),
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      final state = await c.read(postProvider('100').future);
      expect(state.allowReply, isFalse);
    });

    test('missing closed and allowreply keeps reply enabled', () async {
      final adapter = _ViewthreadAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith((ref) => S1HttpClient.test(c, dio)),
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(postProvider('100'), (_, __) {});
      addTearDown(sub.close);

      final state = await c.read(postProvider('100').future);
      expect(state.allowReply, isTrue);
    });
  });
}

class _ViewthreadAdapter implements HttpClientAdapter {
  /// v4 返回 503 的页码。
  final unstablePages = <int>{};

  /// v1 也返回 503 的页码（模拟两个版本都挂）。
  final brokenInV1 = <int>{};

  final requests = <({int page, String version})>[];

  /// 让 `thread.closed` 返回 1（锁帖）。
  bool threadClosed = false;

  List<String> get requestedVersions => [for (final r in requests) r.version];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    if (!uri.query.contains('module=viewthread')) {
      return ResponseBody.fromString('{}', 200);
    }

    final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
    final version = uri.queryParameters['version'] ?? '4';
    requests.add((page: page, version: version));

    final shouldFail = brokenInV1.contains(page) ||
        (version == '4' && unstablePages.contains(page));
    if (shouldFail) {
      return ResponseBody.fromString(
        '<html><title>stage1st.com - System Error</title></html>',
        503,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
          'retry-after': ['3600'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'Variables': {
          'ppp': '40',
          'thread': {
            'subject': 'Test Thread',
            'fid': '4',
            'replies': '79',
            'closed': threadClosed ? '1' : '0',
          },
          'postlist': [
            {
              'pid': '${page}01',
              'author': 'user',
              'authorid': '1',
              'message': 'body',
              'dateline': '1700000000',
              'dbdateline': '1700000000',
              'floor': '1',
              'number': '${(page - 1) * 40 + 1}',
            },
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
