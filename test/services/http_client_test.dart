import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/resource_domains.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  test('auth image headers set Referer and Accept', () {
    final options = RequestOptions(
      path: 'https://img.stage1st.com/forum/a.png',
    );
    S1HttpClient.applyAuthImageHeaders(options);
    expect(options.headers['Referer'], ResourceDomains.defaultReferer);
    expect(options.headers['Accept'], 'image/*,*/*;q=0.8');
  });

  test('auth image headers keep an existing Referer', () {
    final options = RequestOptions(
      path: 'https://img.stage1st.com/forum/a.png',
      headers: {'Referer': 'https://stage1st.com/2b/forum.php'},
    );
    S1HttpClient.applyAuthImageHeaders(options);
    expect(options.headers['Referer'], 'https://stage1st.com/2b/forum.php');
  });

  test('auth image session cookies copy API-domain cookies', () {
    final options = RequestOptions(
      path: 'https://img.stage1st.com/forum/a.png',
    );
    S1HttpClient.applyAuthImageSessionCookies(options, [
      Cookie('${ResourceDomains.cookiePrefix}auth', 'token')..path = '/',
      Cookie('${ResourceDomains.cookiePrefix}saltkey', 'salt')..path = '/',
      Cookie('unrelated', 'nope')..path = '/',
    ]);
    expect(
      options.headers['Cookie'],
      '${ResourceDomains.cookiePrefix}auth=token; '
      '${ResourceDomains.cookiePrefix}saltkey=salt',
    );
  });

  test('serializes concurrent request rate-limit admission', () async {
    var now = DateTime(2026);
    final waits = <Duration>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = S1HttpClient.test(
      container,
      Dio(),
      now: () => now,
      delay: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
    );

    await Future.wait(
      List.generate(5, (_) => client.debugEnforceRateLimit()),
    );

    expect(waits, [const Duration(seconds: 1), const Duration(seconds: 1)]);
  });

  test('media rate limit uses a separate bucket at the same cap', () async {
    var now = DateTime(2026);
    final waits = <Duration>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = S1HttpClient.test(
      container,
      Dio(),
      now: () => now,
      delay: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
    );

    // API 与媒体各 2/s：互不抢队列，合计可同时进 4 个。
    await Future.wait([
      client.debugEnforceRateLimit(),
      client.debugEnforceRateLimit(),
      client.debugEnforceRateLimit(isMedia: true),
      client.debugEnforceRateLimit(isMedia: true),
    ]);
    expect(waits, isEmpty);

    // 再挤一个媒体请求会进入下一秒窗口。
    await client.debugEnforceRateLimit(isMedia: true);
    expect(waits, [const Duration(seconds: 1)]);
  });
}
