import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/forum_list_provider.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('ForumListNotifier', () {
    late _ForumListAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = _ForumListAdapter();
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

    test('build loads forum categories from API', () async {
      final sub = container.listen(forumListProvider, (_, __) {});
      addTearDown(sub.close);

      final forums = await container.read(forumListProvider.future);

      expect(adapter.forumIndexRequests, 1);
      expect(forums, hasLength(1));
      expect(forums.single.name, '主论坛');
      expect(forums.single.subforums.single.name, '游戏论坛');
    });

    test('refresh reloads forum list', () async {
      final sub = container.listen(forumListProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(forumListProvider.future);
      adapter.forumIndexRequests = 0;

      await container.read(forumListProvider.notifier).refresh();
      final forums = await container.read(forumListProvider.future);

      expect(adapter.forumIndexRequests, 1);
      expect(forums.single.subforums.single.fid, '4');
    });
  });
}

class _ForumListAdapter implements HttpClientAdapter {
  int forumIndexRequests = 0;
  bool failNext = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.queryParameters['module'] == 'forumindex') {
      forumIndexRequests++;
      if (failNext) {
        return ResponseBody.fromString('not json', 500);
      }
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {
            'catlist': [
              {
                'fid': '1',
                'name': '主论坛',
                'forums': ['4'],
              },
            ],
            'forumlist': [
              {
                'fid': '4',
                'name': '游戏论坛',
                'description': 'desc',
                'threads': '10',
                'posts': '20',
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
