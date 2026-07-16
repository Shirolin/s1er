import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/http_client.dart';

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
}
