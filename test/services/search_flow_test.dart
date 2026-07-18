import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  test('主题搜索跟随 Discuz POST 302 并解析结果页', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _SearchRedirectAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiService(S1HttpClient.test(container, dio));

    final page = await api.searchForum(query: 'Switch 2');

    expect(page.error, isNull);
    expect(page.count, 1);
    expect(page.hits.single.tid, '2300001');
    expect(adapter.searchPostFollowRedirects, isFalse);
    expect(adapter.requestedSearchResult, isTrue);
  });
}

class _SearchRedirectAdapter implements HttpClientAdapter {
  bool? searchPostFollowRedirects;
  bool requestedSearchResult = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/api/mobile/index.php')) {
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {'formhash': 'fresh-formhash'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'POST' && options.uri.path.endsWith('/search.php')) {
      searchPostFollowRedirects = options.followRedirects;
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            '/2b/search.php?mod=forum&searchid=98765&searchsubmit=yes',
          ],
        },
      );
    }

    if (options.method == 'GET' &&
        options.uri.queryParameters['searchid'] == '98765') {
      requestedSearchResult = true;
      return ResponseBody.fromString(
        '''
<html><body>
  <div class="sttl"><em>找到 “Switch 2” 相关内容 1 个</em></div>
  <ul>
    <li class="pbw">
      <h3><a href="thread-2300001-1-1.html">移动模板主题</a></h3>
      <p>移动模板摘要</p>
      <p><a>游戏论坛</a><span>mobile_user</span><span>2026-7-14 20:00</span></p>
    </li>
  </ul>
</body></html>
''',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }

    return ResponseBody.fromString('Not found', 404);
  }
}
