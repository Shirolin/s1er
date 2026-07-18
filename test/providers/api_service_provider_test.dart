import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/api_service_provider.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  test('apiServiceProvider reuses the same ApiService instance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(apiServiceProvider);
    final second = container.read(apiServiceProvider);

    expect(identical(first, second), isTrue);
    expect(first, isA<ApiService>());
    expect(container.read(httpClientProvider), isA<S1HttpClient>());
  });
}
