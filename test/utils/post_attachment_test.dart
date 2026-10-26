import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/post_attachment.dart';
import 'package:s1er/utils/bbcode_parser.dart';

/// 论坛登录态下 `postlist[].attachments` 会按 aid 给出附件元数据，
/// 正文仍是 `[attach]aid[/attach]`。这里锁定「按下发数据还原」的规则。
void main() {
  const imageAttachment = PostAttachment(
    aid: '2155919',
    filename: 'QQ截图.png',
    path: '202610/13/154803pzzyvpddgdljlzjh.png',
    baseUrl: 'https://img.stage1st.com/forum/',
    isImage: true,
    attachImg: true,
    sizeLabel: '99.34 KB',
  );

  group('PostAttachment', () {
    test('parses map keyed by aid', () {
      final map = PostAttachment.parseMap({
        '2155919': {
          'aid': '2155919',
          'filename': 'QQ截图.png',
          'attachment': '202610/13/154803.png',
          'url': 'https://img.stage1st.com/forum/',
          'isimage': '1',
          'attachimg': '1',
          'attachsize': '99.34 KB',
          'width': '371',
          'height': '482',
        },
      });
      final attachment = map['2155919']!;
      expect(
        attachment.imageUrl,
        'https://img.stage1st.com/forum/202610/13/154803.png',
      );
      expect(attachment.isRenderable, isTrue);
      expect(attachment.width, 371);
      expect(attachment.height, 482);
    });

    test('tolerates empty array (no attachments)', () {
      expect(PostAttachment.parseMap(const []), isEmpty);
      expect(PostAttachment.parseMap(null), isEmpty);
    });

    test('accepts absolute path without base url', () {
      const attachment = PostAttachment(
        aid: '1',
        path: 'https://img.stage1st.com/a.png',
      );
      expect(attachment.imageUrl, 'https://img.stage1st.com/a.png');
    });

    test('label falls back to aid when filename missing', () {
      const attachment = PostAttachment(aid: '42');
      expect(attachment.label, '附件 42');
    });
  });

  group('BbcodeParser attachments', () {
    test('[attach] renders image when metadata is available', () {
      final html = BbcodeParser.parse(
        '正文<br />\n[attach]2155919[/attach]<br />',
        attachments: const {'2155919': imageAttachment},
      );
      expect(
        html,
        contains(
          'data-full="https://img.stage1st.com/forum/202610/13/154803pzzyvpddgdljlzjh.png"',
        ),
      );
      expect(html, isNot(contains('[attach]')));
      expect(html, contains('正文'));
    });

    test('non-image attachment renders labelled placeholder', () {
      const zip = PostAttachment(
        aid: '900',
        filename: '素材.zip',
        path: '202610/13/abc.zip',
        baseUrl: 'https://img.stage1st.com/forum/',
        sizeLabel: '1.2 MB',
      );
      final html = BbcodeParser.parse(
        '[attach]900[/attach]',
        attachments: const {'900': zip},
      );
      expect(html, contains('附件：素材.zip（1.2 MB）'));
      expect(html, isNot(contains('src="')));
    });

    test('unknown aid keeps the raw tag', () {
      final html = BbcodeParser.parse(
        '[attach]123[/attach]',
        attachments: const {'999': imageAttachment},
      );
      expect(html, contains('[attach]123[/attach]'));
    });

    test('without attachments the tag is untouched', () {
      final html = BbcodeParser.parse('[attach]2155919[/attach]');
      expect(html, contains('[attach]2155919[/attach]'));
    });
  });

  group('Post.fromJson', () {
    test('reads attachments from postlist entry', () {
      final post = Post.fromJson({
        'pid': '70365643',
        'message': '正文[attach]2155919[/attach]',
        'author': 'adw667',
        'authorid': '508776',
        'number': '2680',
        'dbdateline': '1791877683',
        'attachments': {
          '2155919': {
            'aid': '2155919',
            'filename': 'QQ截图.png',
            'attachment': '202610/13/154803.png',
            'url': 'https://img.stage1st.com/forum/',
            'isimage': '1',
          },
        },
      });
      expect(post.attachments, hasLength(1));
      expect(post.attachments['2155919']!.filename, 'QQ截图.png');
      expect(post.floor, 2680);
    });

    test('missing attachments key yields empty map', () {
      final post = Post.fromJson({'pid': '1', 'message': 'x'});
      expect(post.attachments, isEmpty);
    });
  });
}
