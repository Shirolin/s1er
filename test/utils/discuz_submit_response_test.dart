import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/discuz_submit_response.dart';

void main() {
  group('DiscuzSubmitResponse.parseReplyAjaxBody', () {
    test('succeedhandle_ empty suffix with meta', () {
      const xml =
          "<script>succeedhandle_('forum.php?mod=viewthread&tid=1&pid=2', 'ok', {'fid':'4','tid':'1','pid':'2'});</script>";
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '2');
      expect(result.tid, '1');
    });

    test('two-arg succeedhandle without meta object', () {
      const xml =
          "<script>succeedhandle_('forum.php?mod=viewthread&tid=9&pid=8', '回复发布成功');</script>";
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '8');
      expect(result.tid, '9');
    });

    test('typeof succeedhandle without call is uncertain', () {
      const xml =
          "<script>if(typeof succeedhandle_=='function') { /* no call */ }</script>";
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isUncertain, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('errorhandle_reply prefers second arg when first empty', () {
      const xml = "<script>errorhandle_reply('', '操作失败');</script>";
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isSuccess, isFalse);
      expect(result.message, '操作失败');
    });

    test('does not reject success messagetext', () {
      const xml = '''<div class="tip">
<dt id="messagetext">
<p>非常感谢，回复发布成功，现在将转入主题页，请稍候……</p>
<script>window.location.href='forum.php?mod=viewthread&tid=100&pid=200';</script>
</dt></div>''';
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isSuccess, isTrue);
      expect(result.isUncertain, isFalse);
      expect(result.pid, '200');
      expect(result.tid, '100');
    });

    test('generic errorhandle_ rejection', () {
      const xml = "<script>errorhandle_foo('内容过长', 'detail');</script>";
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isSuccess, isFalse);
      expect(result.message, '内容过长');
    });

    test('unknown body becomes uncertain not success-text error', () {
      const xml = '<p>unexpected</p>';
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(xml);
      expect(result.isUncertain, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('状态不明确'));
    });

    test('coerces utf8 byte body', () {
      const text =
          "<script>succeedhandle_('forum.php?mod=viewthread&tid=3&pid=4', 'ok');</script>";
      final bytes = utf8.encode(text);
      final result = DiscuzSubmitResponse.parseReplyAjaxBody(bytes);
      expect(result.isSuccess, isTrue);
      expect(result.tid, '3');
      expect(result.pid, '4');
    });
  });

  group('DiscuzSubmitResponse.parseSendReplyMobileBody', () {
    test('json success with variables', () {
      final result = DiscuzSubmitResponse.parseSendReplyMobileBody({
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

    test('json with only Chinese messagestr is success', () {
      final result = DiscuzSubmitResponse.parseSendReplyMobileBody({
        'Message': {
          'messageval': '',
          'messagestr': '非常感谢，回复发布成功，现在将转入主题页',
        },
        'Variables': {'pid': '55', 'tid': '66'},
      });
      expect(result.isSuccess, isTrue);
      expect(result.isUncertain, isFalse);
    });

    test('json utf8 bytes without plain response type', () {
      const json =
          '{"Message":{"messageval":"post_reply_succeed"},"Variables":{"pid":"1","tid":"2"}}';
      final result =
          DiscuzSubmitResponse.parseSendReplyMobileBody(utf8.encode(json));
      expect(result.isSuccess, isTrue);
      expect(result.pid, '1');
      expect(result.tid, '2');
    });

    test('bare mobile key is rejected', () {
      final result = DiscuzSubmitResponse.parseSendReplyMobileBody(
        'mobile:post_reply_nopermission',
      );
      expect(result.isSuccess, isFalse);
      expect(result.message, isNotNull);
    });
  });

  group('DiscuzSubmitResponse.looksLikePostSuccessMessage', () {
    test('never classifies permission errors as success', () {
      expect(
        DiscuzSubmitResponse.looksLikePostSuccessMessage('您没有权限回复'),
        isFalse,
      );
    });
  });
}
