import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/server_notice.dart';

void main() {
  group('ServerNotice.fromJson', () {
    test('reads top-level error when Variables absent', () {
      expect(
        ServerNotice.fromJson({'error': '维护公告 又被爬了'}),
        '维护公告 又被爬了',
      );
    });

    test('prefers Variables.error when Variables present (S1-Orange)', () {
      expect(
        ServerNotice.fromJson({
          'error': '顶层在此场景不作数',
          'Variables': {'error': '维护公告 A'},
        }),
        '维护公告 A',
      );
      expect(ServerNotice.fromJson({'Variables': <String, dynamic>{}}), isNull);
    });

    test('filters to_login and blank messages', () {
      expect(ServerNotice.fromJson({'error': 'to_login'}), isNull);
      expect(ServerNotice.fromJson({'error': '   '}), isNull);
      expect(
        ServerNotice.fromJson({
          'Variables': {'error': 'to_login'},
        }),
        isNull,
      );
      expect(ServerNotice.fromJson(<String, dynamic>{}), isNull);
    });
  });

  group('ServerNotice.fromResponseBody', () {
    test('reads JSON map and JSON string', () {
      expect(ServerNotice.fromResponseBody({'error': '公告'}), '公告');
      expect(ServerNotice.fromResponseBody('{"error":"公告"}'), '公告');
    });

    test('extracts Discuz messagetext prompt page', () {
      const html = '<!DOCTYPE html><html><body>'
          '<div id="messagetext" class="alert_error"><p>姨妈一会，太卡了</p></div>'
          '</body></html>';
      expect(ServerNotice.fromResponseBody(html), '姨妈一会，太卡了');
    });

    test('extracts truncated real S1 snippet ending before closing div', () {
      const html = '<div id="messagetext" class="alert_error">\n'
          '<p>姨妈一会，太卡了</p>\n'
          '<script type="text/javascript">';
      expect(ServerNotice.fromResponseBody(html), '姨妈一会，太卡了');
    });

    test('extracts standalone alert_error div without p wrapper', () {
      const html =
          '<html><body><div class="alert_error">服务器开小差了</div></body></html>';
      expect(ServerNotice.fromResponseBody(html), '服务器开小差了');
    });

    test('does not scan gateway div.info in success bodies', () {
      const html = '<html><body>'
          '<div class="info"><ul><li>502 网关错误</li></ul></div>'
          '</body></html>';
      expect(ServerNotice.fromResponseBody(html), isNull);
    });

    test('ignores binary bytes, plain text and null', () {
      expect(ServerNotice.fromResponseBody([0x89, 0x50, 0x4e, 0x47]), isNull);
      expect(ServerNotice.fromResponseBody('504 Gateway Time-out'), isNull);
      expect(ServerNotice.fromResponseBody(null), isNull);
    });
  });

  group('ServerNotice.fromErrorBody', () {
    test('extracts gateway div.info li (S1-Next selector)', () {
      const html = '<html><body>'
          '<div class="info"><ul><li>论坛维护中，请稍后再试</li></ul></div>'
          '</body></html>';
      expect(ServerNotice.fromErrorBody(html), '论坛维护中，请稍后再试');
      expect(
        ServerNotice.fromErrorBody('<div class="info"><li>维护公告</li></div>'),
        '维护公告',
      );
    });

    test('reads JSON error bodies', () {
      expect(ServerNotice.fromErrorBody({'error': '维护公告'}), '维护公告');
      expect(ServerNotice.fromErrorBody('{"error":"维护公告"}'), '维护公告');
    });

    test('plain gateway text yields null (no fabrication)', () {
      expect(ServerNotice.fromErrorBody('502 Bad Gateway'), isNull);
      expect(ServerNotice.fromErrorBody(null), isNull);
    });
  });
}
