import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/formhash_service.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('ensureFormhash force refresh contract', () {
    test('force clears cached formhash and fetches a fresh thread formhash',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(formhashProvider.notifier).update('consumed_after_login');

      final adapter = _FormhashAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);

      final hasFormhash = await client.ensureFormhash(
        tid: '123',
        fid: '4',
        force: true,
      );

      expect(hasFormhash, isTrue);
      expect(container.read(formhashProvider), 'fresh_from_viewthread');
      expect(adapter.requestedUrls, hasLength(1));
      expect(adapter.requestedUrls.single, contains('module=viewthread'));
      expect(adapter.requestedUrls.single, contains('tid=123'));
    });

    test('without force reuses cached formhash without network fetch',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(formhashProvider.notifier).update('cached_formhash');

      final adapter = _FormhashAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);

      final hasFormhash = await client.ensureFormhash(tid: '123', fid: '4');

      expect(hasFormhash, isTrue);
      expect(container.read(formhashProvider), 'cached_formhash');
      expect(adapter.requestedUrls, isEmpty);
    });
  });
}

class _FormhashAdapter implements HttpClientAdapter {
  final requestedUrls = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    return ResponseBody.fromString(
      '{"Variables":{"formhash":"fresh_from_viewthread"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
