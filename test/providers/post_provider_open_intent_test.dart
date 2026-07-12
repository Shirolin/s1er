import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/models/thread_open_intent.dart';
import 'package:s1_app/providers/post_provider.dart';
import 'package:s1_app/providers/reading_history_provider.dart';
import 'package:s1_app/providers/thread_open_intent_provider.dart';
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

    test('A2 initialPage=5 loads page 5 on first request', () async {
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent(initialPage: 5),
          ),
        ],
      );

      final state = await container.read(postProvider('100').future);

      expect(state.currentPage, 5);
      expect(adapter.requestedPages, [5]);
      expect(adapter.requestedPages, isNot(contains(1)));
    });

    test('A5/A6 targetPid locates page before loading detail', () async {
      adapter.locatePageForPid['999'] = 187;
      container = buildContainer(
        extraOverrides: [
          threadOpenIntentProvider('100').overrideWithValue(
            const ThreadOpenIntent(targetPid: '999'),
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
    });

    test('reading record resume loads lastReadPage without page=1 flash',
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
              lastReadFloor: 1,
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
    });

    test('skips rate log html fetch when commentcount has no rates', () async {
      adapter.commentCount = {'1': 0};
      container = buildContainer(
        extraOverrides: [
          readingRecordProvider('100').overrideWithValue(null),
        ],
      );

      await container.read(postProvider('100').future);

      expect(adapter.rateLogRequests, isEmpty);
    });
  });
}

class _ThreadDetailAdapter implements HttpClientAdapter {
  final requestedPages = <int>[];
  final locateRequests = <String>[];
  final locatePageForPid = <String, int>{};
  final rateLogRequests = <Uri>[];
  Map<String, int>? commentCount;

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
            'pid': '1',
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
      return ResponseBody.fromString('<html></html>', 200);
    }

    return ResponseBody.fromString('{}', 200);
  }
}
