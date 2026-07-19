import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/http_client.dart';

void main() {
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
