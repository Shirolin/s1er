import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/quote_info.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('QuoteInfo.tryParse', () {
    test('parses noticeauthor and noticetrimstr', () {
      const xml = '''
<root>
<input type="hidden" name="noticeauthor" value="d755encoded" />
<input type="hidden" name="noticetrimstr" value="[post][url=forum.php?mod=redirect&amp;goto=findpost&amp;pid=1&amp;ptid=2]a[/url][/post]" />
</root>
''';
      final info = QuoteInfo.tryParse(xml);
      expect(info?.noticeAuthor, 'd755encoded');
      expect(info?.noticeTrimStr, contains('goto=findpost'));
      expect(info?.noticeTrimStr, contains('&ptid=2'));
      expect(info?.noticeTrimStr, isNot(contains('&amp;')));
    });

    test('returns null when fields missing', () {
      expect(QuoteInfo.tryParse('<root></root>'), isNull);
    });
  });

  group('QuoteInfo.submitNoticeTrimStr', () {
    test('rewrites [post] wrapper to [quote], keeps findpost', () {
      const info = QuoteInfo(
        noticeAuthor: 'd755encoded',
        noticeTrimStr:
            '[post][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]a[/url][/post]',
      );
      expect(
        info.submitNoticeTrimStr,
        '[quote][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]a[/url][/quote]',
      );
      expect(info.submitNoticeTrimStr, isNot(contains('[post]')));
      expect(info.submitNoticeTrimStr, contains('goto=findpost'));
    });

    test('leaves already-[quote] trim unchanged', () {
      const trim =
          '[quote][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]'
          'bob[/url] body[/quote]';
      const info = QuoteInfo(noticeAuthor: 'x', noticeTrimStr: trim);
      expect(info.submitNoticeTrimStr, trim);
    });

    test('rewrites case-insensitively', () {
      const info = QuoteInfo(
        noticeAuthor: 'x',
        noticeTrimStr: '[POST]inner[/POST]',
      );
      expect(info.submitNoticeTrimStr, '[quote]inner[/quote]');
    });
  });

  group('ApiService.parseSendReplyResponse', () {
    test('success with Variables pid/tid', () {
      final result = ApiService.parseSendReplyResponse({
        'Message': {
          'messageval': 'post_reply_succeed',
          'messagestr': '回复发布成功',
        },
        'Variables': {'pid': '99', 'tid': '88'},
      });
      expect(result.isSuccess, isTrue);
      expect(result.pid, '99');
      expect(result.tid, '88');
    });

    test('maps mobile:post_reply_toofast', () {
      final result = ApiService.parseSendReplyResponse({
        'Message': {
          'messageval': 'mobile:post_reply_toofast',
          'messagestr': 'post_reply_toofast',
        },
      });
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('间隔过短'));
    });

    test('falls back to XML parser', () {
      const xml =
          "<root><![CDATA[<script>succeedhandle_reply('r', 'ok', {fid:'4',tid:'456',pid:'123'});</script>]]></root>";
      final result = ApiService.parseSendReplyResponse(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '123');
    });
  });
}
