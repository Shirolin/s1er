import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/api_config.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  test('permission error blocks submission even when types are returned',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([
      '{"Variables":{"formhash":"fh","threadtypes":{"required":"1","types":{"1":"分类"}}},"Message":{"messageval":"postperm_login_nopermission_mobile","messagestr":"mobile:postperm_login_nopermission_mobile"}}',
    ]);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );

    final result = await api.submitNewThread(
      fid: '4',
      subject: '标题',
      message: '正文',
      typeId: '1',
    );

    expect(result.isSuccess, isFalse);
    expect(result.error, isNotNull);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  test('allowed form submits the newthread field contract once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([
      '{"Variables":{"formhash":"fh","threadtypes":{"required":"1","types":{"1":"分类"}}},"Message":{}}',
      '{"Variables":{"tid":"900","pid":"901"},"Message":{"messageval":"post_newthread_succeed","messagestr":"succeed"}}',
    ]);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );

    final result = await api.submitNewThread(
      fid: '4',
      subject: '标题',
      message: '正文',
      typeId: '1',
    );

    expect(result.isSuccess, isTrue);
    expect(result.tid, '900');
    expect(adapter.requests, hasLength(2));
    final request = adapter.requests[1];
    expect(request.method, 'POST');
    expect(request.path, contains('module=${ApiConfig.moduleNewThread}'));
    expect(request.path, contains('topicsubmit=yes'));
    final data = request.data as Map;
    expect(data['formhash'], 'fh');
    expect(data['typeid'], '1');
    expect(data['subject'], '标题');
    expect(data['message'], '正文');
    expect(data['allownoticeauthor'], '1');
    expect(data['usesig'], '1');
    expect(data.containsKey('save'), isFalse);
  });

  test('successful marker without tid is treated as unknown failure', () {
    final result = ApiService.parseNewThreadSubmitResponse({
      'Message': {'messageval': 'post_newthread_succeed'},
      'Variables': {'pid': '1'},
    });
    expect(result.isSuccess, isFalse);
    expect(result.error, contains('主题编号'));
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.responses);

  final List<String> responses;
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
    return ResponseBody.fromString(
      responses[requests.length - 1],
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
