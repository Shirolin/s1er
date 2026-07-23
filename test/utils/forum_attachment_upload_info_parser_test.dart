import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/forum_attachment_upload_info_parser.dart';
import 'package:s1er/utils/forum_attachment_submit.dart';

void main() {
  group('parseForumAttachmentUploadInfo', () {
    test('reads hash uid fid from form inputs', () {
      const html = '''
<form action="misc.php?mod=swfupload&operation=upload&fid=4">
<input type="hidden" name="uid" value="426519" />
<input type="hidden" name="hash" value="ee9699596ff7c4584b5e39c8cdf11d34" />
<input type="hidden" name="fid" value="4" />
<input type="hidden" name="formhash" value="abcdef12" />
</form>
''';
      final info = parseForumAttachmentUploadInfo(html);
      expect(info, isNotNull);
      expect(info!.hash, 'ee9699596ff7c4584b5e39c8cdf11d34');
      expect(info.uid, '426519');
      expect(info.fid, '4');
      expect(info.formhash, 'abcdef12');
      expect(info.uploadUrl, contains('operation=upload'));
    });

    test('falls back to post_params script', () {
      const html = '''
<script>
var upload_url = "misc.php?mod=swfupload&operation=upload&fid=51";
var post_params = {"uid":"1","hash":"abc123hash","fid":"51"};
</script>
''';
      final info = parseForumAttachmentUploadInfo(html);
      expect(info, isNotNull);
      expect(info!.hash, 'abc123hash');
      expect(info.uid, '1');
      expect(info.fid, '51');
    });

    test('parses touch template uploadformdata and uploadurl', () {
      const html = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[
<form method="post" id="postform" action="forum.php?mod=post&action=reply&fid=4&tid=1&mobile=2">
<input type="hidden" name="formhash" id="formhash" value="5ac91bb7" />
<textarea id="needmessage" name="message"></textarea>
</form>
<script type="text/javascript">
\$(document).on('change', '#filedata', function() {
\$.buildfileupload({
uploadurl:'misc.php?mod=swfupload&operation=upload&type=image&inajax=yes&infloat=yes&simple=2',
uploadformdata:{uid:"426519", hash:"ee9699596ff7c4584b5e39c8cdf11d34"},
uploadinputname:'Filedata',
});
});
</script>
]]></root>
''';
      final info = parseForumAttachmentUploadInfo(html, fallbackFid: '4');
      expect(info, isNotNull);
      expect(info!.hash, 'ee9699596ff7c4584b5e39c8cdf11d34');
      expect(info.uid, '426519');
      expect(info.fid, '4');
      expect(info.formhash, '5ac91bb7');
      expect(info.uploadUrl, contains('simple=2'));
      expect(info.uploadUrl, contains('type=image'));
    });

    test('prefers post_params over uploadformdata when both exist', () {
      const html = '''
<script>
var upload_url = "misc.php?mod=swfupload&action=swfupload&operation=upload&fid=4";
var post_params = {"uid":"1","hash":"desktopHash","fid":"4"};
uploadformdata:{uid:"9", hash:"mobileHash"};
uploadurl:'misc.php?mod=swfupload&operation=upload&type=image&simple=2';
</script>
''';
      final info = parseForumAttachmentUploadInfo(html, fallbackFid: '4');
      expect(info, isNotNull);
      expect(info!.hash, 'desktopHash');
      expect(info.uploadUrl, contains('action=swfupload'));
    });

    test('uses fallbackFid when form omits fid', () {
      const html = '''
<input type="hidden" name="hash" value="onlyhash" />
<input type="hidden" name="uid" value="9" />
''';
      final info = parseForumAttachmentUploadInfo(html, fallbackFid: '6');
      expect(info, isNotNull);
      expect(info!.fid, '6');
      expect(info.hash, 'onlyhash');
    });
  });

  group('parseForumAttachmentUploadAid', () {
    test('parses plain aid', () {
      expect(parseForumAttachmentUploadAid('2105474'), '2105474');
    });

    test('parses DISCUZUPLOAD desktop pipe format', () {
      expect(
        parseForumAttachmentUploadAid('DISCUZUPLOAD|0|2105474|1|0'),
        '2105474',
      );
    });

    test('parses DISCUZUPLOAD mobile simple=2 success', () {
      expect(
        parseForumAttachmentUploadAid(
          'DISCUZUPLOAD|1|0|2105474|1|202407/xx.jpg|jpg',
        ),
        '2105474',
      );
      expect(
        parseForumAttachmentUploadAid(
          'DISCUZUPLOAD|0|0|2105999|1|202407/yy.png|png',
        ),
        '2105999',
      );
    });

    test('rejects failure responses', () {
      expect(parseForumAttachmentUploadAid('DISCUZUPLOAD|1|ban'), isNull);
      expect(parseForumAttachmentUploadAid('DISCUZUPLOAD|1|1|0'), isNull);
      expect(parseForumAttachmentUploadAid(''), isNull);
    });
  });

  group('parseForumAttachmentUploadPreviewUrl', () {
    test('builds img CDN url from simple=2 path', () {
      expect(
        parseForumAttachmentUploadPreviewUrl(
          'DISCUZUPLOAD|1|0|2105474|1|202407/xx.jpg|jpg',
        ),
        'https://img.stage1st.com/forum/202407/xx.jpg',
      );
    });
  });

  group('forumAttachmentUploadErrorMessage', () {
    test('maps known reasons', () {
      expect(
        forumAttachmentUploadErrorMessage('DISCUZUPLOAD|1|ban'),
        '附件类型被禁止',
      );
      expect(
        forumAttachmentUploadErrorMessage('DISCUZUPLOAD|1|perday'),
        '今日附件上传额度不足',
      );
    });

    test('maps mobile STATUSMSG codes', () {
      expect(
        forumAttachmentUploadErrorMessage('DISCUZUPLOAD|1|6|0||||'),
        '今日您已无法上传更多的附件',
      );
      expect(
        forumAttachmentUploadErrorMessage('DISCUZUPLOAD|1|1|0||||ban'),
        '附件类型被禁止',
      );
    });

    test('maps login tip html', () {
      expect(
        forumAttachmentUploadErrorMessage('<root>请先登录</root>'),
        '请先登录后再上传图片',
      );
    });
  });

  group('parseForumAttachmentImageList', () {
    test('extracts image_ aid src', () {
      const html = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[
<img src="forum.php?mod=image&aid=2105474&size=300x300" id="image_2105474" />
]]></root>
''';
      final map = parseForumAttachmentImageList(html);
      expect(map['2105474'], contains('aid=2105474'));
      expect(map['2105474'], startsWith('https://'));
    });
  });

  group('forum_attachment_submit', () {
    test('collects attachimg aids', () {
      const msg = '看图[attachimg]12[/attachimg]和[attachimg]34[/attachimg]';
      expect(collectForumAttachmentIds(msg), {'12', '34'});
      expect(hasForumAttachments(msg), isTrue);
    });

    test('appendAttachNewFields writes description and readperm', () {
      final fields = <String, String>{};
      appendAttachNewFields(fields, {'2105474'});
      expect(fields['attachnew[2105474][description]'], '');
      expect(fields['attachnew[2105474][readperm]'], '');
    });

    test('normalizeForumAttachmentMessage rewrites forum img aid', () {
      const raw =
          '[img]https://stage1st.com/2b/forum.php?mod=image&aid=99[/img]';
      expect(
        normalizeForumAttachmentMessage(raw),
        '[attachimg]99[/attachimg]',
      );
    });
  });
}
