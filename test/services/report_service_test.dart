import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/api_config.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  test('report form and submit use the expected Web endpoints', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter(
      responses: [
        '''<form><input name="formhash" value="fh" /><input name="rid" value="2" /></form>''',
        '举报成功',
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final service = ApiService(S1HttpClient.test(container, dio));

    final form = await service.fetchReportForm(
      tid: '1',
      pid: '2',
      fid: '3',
      page: 4,
    );
    expect(form.hasError, isFalse);
    final result = await service.submitReport(
      tid: '1',
      pid: '2',
      fid: '3',
      reason: '违规内容',
      message: '说明',
      form: form,
    );

    expect(result, isNull);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].method, 'GET');
    expect(adapter.requests[0].path, contains('mod=report'));
    expect(adapter.requests[0].path, contains('rtype=post'));
    expect(adapter.requests[0].path, contains('rid=2'));
    expect(adapter.requests[0].path, contains('tid=1'));
    expect(adapter.requests[1].method, 'POST');
    expect(adapter.requests[1].path, ApiConfig.reportSubmitUrl());
    expect(adapter.requests[1].data, isA<Map>());
    final data = adapter.requests[1].data as Map;
    expect(data['formhash'], 'fh');
    expect(data['report_select'], '违规内容');
    expect(data['message'], '说明');
    expect(data['reportsubmit'], 'true');
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({required this.responses});

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
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }
}
