import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('ApiService.login security question', () {
    test('posts questionid and answer when provided', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final adapter = _LoginAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);
      final api = ApiService(client);

      final error = await api.login(
        'alice',
        'secret',
        questionId: 3,
        answer: '上海',
      );

      expect(error, isNull);
      expect(adapter.postBodies, hasLength(1));
      final body = adapter.postBodies.single;
      expect(body['questionid'], '3');
      expect(body['answer'], '上海');
      expect(body['username'], 'alice');
      expect(body['password'], 'secret');
    });

    test('posts empty answer when questionId is 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final adapter = _LoginAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);
      final api = ApiService(client);

      final error = await api.login(
        'alice',
        'secret',
        questionId: 0,
        answer: 'should-be-ignored',
      );

      expect(error, isNull);
      expect(adapter.postBodies.single['questionid'], '0');
      expect(adapter.postBodies.single['answer'], '');
    });

    test('maps mobile:login_invalid to friendly Chinese', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final adapter = _LoginAdapter(
        postResponse: jsonEncode({
          'Message': {
            'messageval': 'mobile:login_invalid',
            'messagestr': 'login_invalid',
          },
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);
      final api = ApiService(client);

      final error = await api.login('alice', 'wrong');
      expect(error, '登录失败，用户名、密码或安全提问不正确。');
    });
  });
}

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter({this.postResponse});

  final postBodies = <Map<String, String>>[];
  final String? postResponse;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {'formhash': 'abcd1234'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final raw = await _readBody(requestStream);
    postBodies.add(Uri.splitQueryString(raw));

    // refreshFormhashAfterAuth may follow with more GETs; succeed login first.
    return ResponseBody.fromString(
      postResponse ??
          jsonEncode({
            'Message': {
              'messageval': 'login_succeed',
              'messagestr': '欢迎您回来',
            },
          }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Future<String> _readBody(Stream<Uint8List>? requestStream) async {
    if (requestStream == null) return '';
    final chunks = await requestStream.toList();
    final bytes = chunks.expand((c) => c).toList();
    return utf8.decode(bytes);
  }
}
