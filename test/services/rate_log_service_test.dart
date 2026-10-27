import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/services/rate_log_service.dart';

const _ratedTableHtml = '''
<table class="list" cellspacing="0" cellpadding="0">
<thead>
<tr>
<td>积分</td>
<td>用户名</td>
<td>时间</td>
<td>理由</td>
</tr>
</thead><tr>
<td>战斗力 +1 鹅</td>
<td><a href="space-uid-541383.html">Alicest</a></td>
<td>2026-8-12 20:27</td>
<td>＋1</td>
</tr>
<tr>
<td>战斗力 -2 鹅</td>
<td><a href="home.php?mod=space&uid=200">someone</a></td>
<td>2026-8-13 09:05</td>
<td>扣分</td>
</tr>
</table>
''';

void main() {
  group('RateLogService.parseRateTable', () {
    test('parses desktop ratings table without tbody', () {
      final log = RateLogService.parseRateTable(
        _ratedTableHtml,
        pid: '70365643',
      );

      expect(log, isNotNull);
      expect(log!.pid, '70365643');
      expect(log.participantCount, 2);
      expect(log.totalScore, -1); // +1 -2
      expect(log.entries, hasLength(2));

      expect(log.entries[0].username, 'Alicest');
      expect(log.entries[0].uid, '541383');
      expect(log.entries[0].score, 1);
      expect(log.entries[0].ratedAt, DateTime(2026, 8, 12, 20, 27));
      expect(log.entries[0].reason, '＋1');

      expect(log.entries[1].username, 'someone');
      expect(log.entries[1].uid, '200');
      expect(log.entries[1].score, -2);
      expect(log.entries[1].reason, '扣分');
    });

    test('skips header row and rows without user link', () {
      const html = '''
<table><tr><td>积分</td><td>用户名</td><td>时间</td><td>理由</td></tr>
<tr><td>战斗力 +2 鹅</td><td><span>无链接</span></td><td>2026-8-12 20:27</td><td>x</td></tr>
<tr><td>战斗力 +2 鹅</td><td><a href="space-uid-1.html">valid</a></td><td>2026-8-12 20:27</td><td>ok</td></tr>
</table>
''';

      final log = RateLogService.parseRateTable(html, pid: '1');

      expect(log, isNotNull);
      expect(log!.entries, hasLength(1));
      expect(log.entries.single.username, 'valid');
      expect(log.participantCount, 1);
    });

    test('returns null for empty or non-table html', () {
      expect(RateLogService.parseRateTable('', pid: '1'), isNull);
      expect(
        RateLogService.parseRateTable(
          '<html><body>无权限</body></html>',
          pid: '1',
        ),
        isNull,
      );
      expect(
        RateLogService.parseRateTable(
          '<table><thead><tr><td>积分</td><td>用户名</td>'
          '<td>时间</td><td>理由</td></tr></thead></table>',
          pid: '1',
        ),
        isNull,
      );
    });
  });

  group('RateLogService.fetchFullRateLog', () {
    test('requests single-post ratings endpoint and parses it', () async {
      final adapter = _RecordingAdapter(_ratedTableHtml);
      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = RateLogService(
        S1HttpClient.test(container, dio, delay: (_) async {}),
      );

      final log = await service.fetchFullRateLog('2135953', '70365643');

      expect(log, isNotNull);
      expect(log!.entries, hasLength(2));
      expect(adapter.uris, hasLength(1));

      final uri = adapter.uris.single;
      expect(uri.path, endsWith('forum.php'));
      expect(uri.queryParameters['mod'], 'misc');
      expect(uri.queryParameters['action'], 'viewratings');
      expect(uri.queryParameters['tid'], '2135953');
      expect(uri.queryParameters['pid'], '70365643');
      expect(uri.queryParameters['inajax'], '1');
      expect(uri.queryParameters['mobile'], 'no');
      expect(uri.queryParameters.containsKey('page'), isFalse);
    });

    test('returns null on request failure', () async {
      final dio = Dio()..httpClientAdapter = _FailingAdapter();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = RateLogService(
        S1HttpClient.test(container, dio, delay: (_) async {}),
      );

      expect(await service.fetchFullRateLog('1', '2'), isNull);
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.html);

  final String html;
  final List<Uri> uris = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri);
    return ResponseBody.fromString(
      html,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      message: 'network down',
    );
  }
}
