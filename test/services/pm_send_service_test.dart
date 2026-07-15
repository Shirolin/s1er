import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  test('login-required preflight never sends a private message', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([
      '{"Variables":{"formhash":"fh"},"Message":{"messageval":"to_login","messagestr":"mobile:to_login"}}',
    ]);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );

    final result = await api.sendPrivateMessage(touid: '123', message: '你好');

    expect(result.isSuccess, isFalse);
    expect(result.isUncertain, isFalse);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  test('successful send follows sendpm contract exactly once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([
      '{"Variables":{"formhash":"fh"},"Message":{}}',
      '{"Variables":{"pmid":"800"},"Message":{"messageval":"do_success","messagestr":"发送成功"}}',
    ]);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );

    final result = await api.sendPrivateMessage(touid: '123', message: ' 你好 ');

    expect(result.isSuccess, isTrue);
    expect(result.pmid, '800');
    expect(adapter.requests, hasLength(2));
    final request = adapter.requests[1];
    expect(request.method, 'POST');
    expect(request.path, contains('module=sendpm'));
    expect(request.path, contains('pmsubmit=true'));
    final data = request.data as Map;
    expect(data['formhash'], 'fh');
    expect(data['touid'], '123');
    expect(data['message'], '你好');
  });

  test('successful status without pmid is uncertain', () {
    final result = ApiService.parsePmSendResponse({
      'Message': {'messageval': 'do_success'},
      'Variables': <String, dynamic>{},
    });
    expect(result.isUncertain, isTrue);
  });

  test('post transport failure is uncertain and never retried', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter(
      ['{"Variables":{"formhash":"fh"},"Message":{}}'],
      throwOnPost: true,
    );
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );

    final result = await api.sendPrivateMessage(touid: '123', message: '你好');

    expect(result.isUncertain, isTrue);
    expect(adapter.requests, hasLength(2));
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.responses, {this.throwOnPost = false});

  final List<String> responses;
  final bool throwOnPost;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (throwOnPost && options.method == 'POST') {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromString(
      responses[requests.length - 1],
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
