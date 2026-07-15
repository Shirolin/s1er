import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/api_config.dart';
import 'package:s1_app/models/attendance_result.dart';
import 'package:s1_app/services/formhash_service.dart';
import 'package:s1_app/services/forum_tools_service.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('ForumToolsService transport', () {
    test('server blacklist uses GET HTML endpoint and parses page', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = _CaptureAdapter(
        responseBody: '''
          <ul id="friend_ul"><li><h4><a href="?uid=7">blocked</a></h4></li></ul>
          <div class="pg"><a href="?page=2">2</a></div>
        ''',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);
      final service = ForumToolsService(client);

      final result =
          await service.getServerBlacklistPage(uid: '426519', page: 1);

      expect(result.items.single.uid, '7');
      expect(result.totalPages, 2);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, contains('view=blacklist'));
      expect(request.path, contains('uid=426519'));
      expect(request.path, contains('page=1'));
    });

    test('friend list uses GET module=friend version=1', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = _CaptureAdapter(
        responseBody: jsonEncode({
          'Variables': {
            'list': [
              {'uid': '1', 'username': 'a'},
            ],
          },
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);
      final service = ForumToolsService(client);

      final result = await service.getFriendList(uid: '426519');
      expect(result.items.single.uid, '1');
      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, contains('module=${ApiConfig.moduleFriend}'));
      expect(req.path, contains('version=${ApiConfig.friendApiVersion}'));
      expect(req.path, contains('uid=426519'));
    });

    test(
      'daily sign GET includes formhash and does not retry on failure',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(formhashProvider.notifier).update('fh123');
        final adapter = _CaptureAdapter(throwOnFetch: true);
        final dio = Dio()..httpClientAdapter = adapter;
        final client = S1HttpClient.test(container, dio);
        final service = ForumToolsService(client);

        final result = await service.dailySign();
        expect(result.outcome, AttendanceOutcome.failed);
        expect(adapter.requests, hasLength(1));
        final req = adapter.requests.single;
        expect(req.method, 'GET');
        expect(
          req.path,
          contains('study_daily_attendance-daily_attendance.html'),
        );
        expect(req.path, contains('inajax=1'));
        expect(req.path, contains('formhash=fh123'));
      },
    );

    test('dark room GET passes cursor and omits formhash', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = _CaptureAdapter(
        responseBody: jsonEncode({
          'message': '1|10',
          'data': <String, dynamic>{},
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = S1HttpClient.test(container, dio);
      final service = ForumToolsService(client);

      await service.getDarkRoom(cursor: '78648');
      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, contains('action=showdarkroom'));
      expect(req.path, contains('ajaxdata=json'));
      expect(req.path, contains('cid=78648'));
      expect(req.path, isNot(contains('formhash=')));
    });
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({this.responseBody, this.throwOnFetch = false});

  final String? responseBody;
  final bool throwOnFetch;
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
    if (throwOnFetch) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'network down',
      );
    }
    return ResponseBody.fromString(
      responseBody ?? '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
