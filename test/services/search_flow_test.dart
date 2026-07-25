import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_search_query.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  test('主题搜索跟随 Discuz POST 302 并解析结果页', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _SearchRedirectAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiService(S1HttpClient.test(container, dio));

    final page = await api.searchForum(
      query: const ForumSearchQuery(keyword: 'Switch 2'),
    );

    expect(page.error, isNull);
    expect(page.count, 1);
    expect(page.hits.single.tid, '2300001');
    expect(adapter.searchPostFollowRedirects, isFalse);
    expect(adapter.requestedSearchResult, isTrue);
    expect(adapter.searchUsesDesktopUa, isTrue);
    expect(adapter.lastSearchPostData?['formhash'], 'fresh-formhash');
    expect(adapter.lastSearchPostData?['srchtxt'], 'Switch 2');
    expect(adapter.lastSearchPostData?['searchsubmit'], 'yes');
  });

  test('主题高级搜索 POST 携带全部筛选字段', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _SearchRedirectAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiService(S1HttpClient.test(container, dio));

    await api.searchForum(
      query: const ForumSearchQuery(
        keyword: 'switch',
        author: 'alice',
        filter: ForumSearchFilter.digest,
        specials: {1, 3},
        srchfromSeconds: 604800,
        before: true,
        orderby: 'views',
        ascending: true,
        forumIds: {'4', '6'},
      ),
    );

    final data = adapter.lastSearchPostData;
    expect(data?['formhash'], 'fresh-formhash');
    expect(data?['srchtxt'], 'switch');
    expect(data?['srchuname'], 'alice');
    expect(data?['srchfilter'], 'digest');
    expect(data?['special'], ['1', '3']);
    expect(data?['srchfrom'], '604800');
    expect(data?['before'], '1');
    expect(data?['orderby'], 'views');
    expect(data?['ascdesc'], 'asc');
    expect(data?['srchfid'], ['4', '6']);
  });

  test('用户搜索跟随 forcemobile 桌面模板', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _SearchRedirectAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiService(S1HttpClient.test(container, dio));

    final page = await api.searchUser(query: 'demo_user');

    expect(page.error, isNull);
    expect(page.hits, hasLength(1));
    expect(page.hits.single.uid, '10001');
    expect(page.hits.single.name, 'demo_user');
    expect(adapter.requestedUserDesktopResult, isTrue);
    expect(adapter.searchUsesDesktopUa, isTrue);
  });
}

class _SearchRedirectAdapter implements HttpClientAdapter {
  bool? searchPostFollowRedirects;
  bool requestedSearchResult = false;
  bool requestedUserDesktopResult = false;
  bool searchUsesDesktopUa = false;
  Map<String, dynamic>? lastSearchPostData;

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
      searchUsesDesktopUa = options.extra['s1DesktopUa'] == true;
      lastSearchPostData = Map<String, dynamic>.from(
        options.data as Map<dynamic, dynamic>,
      );
      final mod = options.uri.queryParameters['mod'];
      if (mod == 'user') {
        return ResponseBody.fromString(
          '''
<html><body>
  <div class="jump_c">
    <p>您访问的页面无手机页面，是否进一步访问电脑版？</p>
    <p><a href="/2b/home.php?mod=spacecp&amp;ac=search&amp;username=demo_user&amp;searchsubmit=yes&amp;forcemobile=1">继续访问</a></p>
  </div>
</body></html>
''',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        );
      }
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
      searchUsesDesktopUa = options.extra['s1DesktopUa'] == true;
      return ResponseBody.fromString(
        '''
<html><body>
  <div class="sttl"><em>找到 “Switch 2” 相关内容 1 个</em></div>
  <ul>
    <li class="pbw">
      <h3><a href="thread-2300001-1-1.html">桌面模板主题</a></h3>
      <p>桌面模板摘要</p>
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

    if (options.method == 'GET' &&
        options.uri.queryParameters['forcemobile'] == '1') {
      requestedUserDesktopResult = true;
      searchUsesDesktopUa = options.extra['s1DesktopUa'] == true;
      return ResponseBody.fromString(
        '''
<html><body>
  <ul>
    <li class="bbda cl">
      <a href="avatar.png"><img src="avatar.png"></a>
      <a href="space-uid-10001.html">demo_user</a>
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
