import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/thread_list_provider.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('ThreadListNotifier', () {
    const fid = '4';
    late _ThreadListAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = _ThreadListAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(c, dio),
          ),
        ],
      );
      container = c;
    });

    tearDown(() {
      container.dispose();
    });

    test('build loads first page with forum name', () async {
      final sub = container.listen(threadListProvider(fid), (_, __) {});
      addTearDown(sub.close);

      final state = await container.read(threadListProvider(fid).future);

      expect(adapter.forumDisplayRequests, 1);
      expect(state.forumName, '游戏论坛');
      expect(state.threads, hasLength(1));
      expect(state.threads.single.tid, '123');
      expect(state.currentPage, 1);
      expect(state.totalPages, 2);
    });

    test('goToPage loads requested page', () async {
      final sub = container.listen(threadListProvider(fid), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider(fid).future);
      adapter.forumDisplayRequests = 0;

      await container.read(threadListProvider(fid).notifier).goToPage(2);

      expect(adapter.forumDisplayRequests, 1);
      final state = container.read(threadListProvider(fid)).asData!.value;
      expect(state.currentPage, 2);
      expect(state.threads.single.subject, 'Page 2 Thread');
    });
  });
}

class _ThreadListAdapter implements HttpClientAdapter {
  int forumDisplayRequests = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.queryParameters['module'] == 'forumdisplay') {
      forumDisplayRequests++;
      final page = int.tryParse(options.uri.queryParameters['page'] ?? '1') ?? 1;
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {
            'forum': {
              'name': '游戏论坛',
              'threads': '60',
            },
            'tpp': '30',
            'forum_threadlist': [
              {
                'tid': page == 1 ? '123' : '456',
                'subject': page == 1 ? 'Test Thread' : 'Page 2 Thread',
                'author': 'alice',
                'authorid': '1',
                'dbdateline': '1700000000',
                'views': '10',
                'replies': '2',
                'fid': '4',
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
    return ResponseBody.fromString('{}', 200);
  }
}
