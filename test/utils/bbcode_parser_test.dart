import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/bbcode_parser.dart';
import 'package:s1er/utils/post_image_index_counter.dart';

void main() {
  group('BbcodeParser post images', () {
    test('preserves anchor href and img src from div.img', () {
      final html = File('test/fixtures/post_images/stage1st_anchor.html')
          .readAsStringSync();
      final parsed = BbcodeParser.parse(html);

      expect(parsed, contains('class="post-image"'));
      expect(parsed, contains('data-preview='));
      expect(parsed, contains('.thumb.jpg'));
      expect(parsed, contains('data-full='));
      expect(parsed, contains('185034y9rw9og8zgzdgct8.png"'));
      expect(parsed, isNot(contains('<img')));
    });

    test(
        'external single-url div.img becomes post-image with same preview/full',
        () {
      final html = File('test/fixtures/post_images/external_single.html')
          .readAsStringSync();
      final parsed = BbcodeParser.parse(html);

      expect(parsed, contains('class="post-image"'));
      expect(parsed, contains('data-preview="https://p.sda1.dev/'));
      expect(parsed, contains('data-full="https://p.sda1.dev/'));
    });

    test('[img] bbcode keeps single URL for stage1st attachment', () {
      const src = 'https://img.stage1st.com/forum/2024/01/a.png';
      final parsed = BbcodeParser.parse('[img]$src[/img]');

      expect(parsed, contains('class="post-image"'));
      expect(parsed, contains('data-preview="$src"'));
      expect(parsed, contains('data-full="$src"'));
    });

    test('[backcolor] becomes background-color span', () {
      final parsed = BbcodeParser.parse('[backcolor=yellow]mark[/backcolor]');
      expect(parsed, contains('background-color:yellow'));
      expect(parsed, contains('mark'));
    });

    test('[hide=N] and [hide] both become hide-content', () {
      final credit = BbcodeParser.parse('[hide=5]secret[/hide]');
      expect(credit, contains('class="hide-content"'));
      expect(credit, contains('secret'));
      expect(credit, isNot(contains('hide=5')));

      final plain = BbcodeParser.parse('[hide]plain[/hide]');
      expect(plain, contains('class="hide-content"'));
      expect(plain, contains('plain'));
    });

    test('extractImages reads data-preview attributes', () {
      const html =
          '<span class="post-image" data-preview="https://a/p.jpg" data-full="https://a/f.jpg"></span>';
      expect(BbcodeParser.extractImages(html), ['https://a/p.jpg']);
    });

    test('assigns sequential data-image-index per post floor', () {
      final counter = PostImageIndexCounter();
      final parsed = BbcodeParser.parse(
        '[img]https://example.com/1.jpg[/img]'
        '[img]https://example.com/2.jpg[/img]',
        imageIndexCounter: counter,
      );

      expect(parsed, contains('data-image-index="0"'));
      expect(parsed, contains('data-image-index="1"'));
      expect(counter.assignedCount, 2);
      expect(BbcodeParser.countPostImages(parsed), 2);
    });

    test('emoticons do not receive data-image-index', () {
      final counter = PostImageIndexCounter();
      final parsed = BbcodeParser.parse(
        '[f:001][img]https://example.com/p.jpg[/img]',
        imageIndexCounter: counter,
      );

      expect(parsed, contains('emoticon'));
      expect(parsed, contains('data-image-index="0"'));
      expect(counter.assignedCount, 1);
    });

    test('converts multi-pack emoticon entities', () {
      final parsed = BbcodeParser.parse('[f:001][c:002][a:003]');
      expect(parsed, contains('data-code="f:001"'));
      expect(parsed, contains('data-code="c:002"'));
      expect(parsed, contains('data-code="a:003"'));
    });

    test('escapes url/img attribute breakout and rejects unsafe colors', () {
      final brokenUrl = BbcodeParser.parse(
        '[url=https://a.com" data-x="1]t[/url]',
      );
      expect(brokenUrl, contains('href="https://a.com&quot; data-x=&quot;1"'));
      expect(brokenUrl, isNot(contains('data-x="1"')));

      final badColor = BbcodeParser.parse(
        '[color=red;background-image:url(https://t.example/p)]hi[/color]',
      );
      expect(badColor, isNot(contains('background-image')));
      expect(badColor, contains('hi'));

      final okColor = BbcodeParser.parse('[color=#ff0000]red[/color]');
      expect(okColor, contains('color:#ff0000'));
    });

    test('strips ratelog h3.psth and div[id^="ratelog_"]', () {
      const input = '正常内容<h3 class="psth xs1">评分</h3>'
          '<div id="ratelog_69941195"><ul class="post_box cl"><li>black -2</li></ul></div>'
          '尾部正常内容';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, contains('正常内容'));
      expect(parsed, contains('尾部正常内容'));
      expect(parsed, isNot(contains('评分')));
      expect(parsed, isNot(contains('ratelog_69941195')));
      expect(parsed, isNot(contains('black -2')));
    });

    test('extracts quote headers and tags depth class', () {
      const input = '<blockquote>'
          '<font size="2"><a href="forum.php?mod=redirect&amp;goto=findpost&amp;pid=123&amp;ptid=456"><font color="#999999">Author 发表于 2026-7-20 12:00</font></a></font><br/>'
          '<blockquote>Nested quote</blockquote>'
          'Outer quote'
          '</blockquote>';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, contains('class="quote-depth-1"'));
      expect(parsed, contains('class="quote-depth-2"'));
      expect(
        parsed,
        contains(
          '<quote-header author="Author 发表于 2026-7-20 12:00" href="forum.php?mod=redirect&amp;goto=findpost&amp;pid=123&amp;ptid=456"></quote-header>',
        ),
      );
    });

    test('converts div.reply_wrap to blockquote and parses correctly', () {
      const input = '<div class="reply_wrap">'
          '<font color="#999999">User 发表于 2026-7-21 11:00</font><br/>'
          'Quote content'
          '</div>';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, contains('<blockquote class="reply_wrap quote-depth-1">'));
      expect(
        parsed,
        contains(
          '<quote-header author="User 发表于 2026-7-21 11:00" href=""></quote-header>',
        ),
      );
      expect(parsed, contains('Quote content'));
    });
  });

  group('form and media tag stripping', () {
    test('removes empty input/button/select and replaces textarea with text',
        () {
      const input = '<input type="text" placeholder="搜索" />'
          '<button>确定</button>'
          '<select><option>A</option></select>'
          '<textarea>内容</textarea>';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, isNot(contains('<input')));
      expect(parsed, isNot(contains('<button')));
      expect(parsed, isNot(contains('<select')));
      expect(parsed, isNot(contains('<textarea')));
      expect(parsed, contains('确定'));
      expect(parsed, contains('内容'));
    });

    test('removes media embed tags entirely', () {
      const input = '<iframe src="https://example.com/embed"></iframe>'
          '<video src="foo.mp4"></video>'
          '<audio src="bar.mp3"></audio>';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, isNot(contains('<iframe')));
      expect(parsed, isNot(contains('<video')));
      expect(parsed, isNot(contains('<audio')));
    });

    test('strips form tags from real-world "moyu" post content', () {
      // Simulate the taxiom post that caused native crashes.
      const input = '摸鱼模式<br/>'
          '<input type="text" placeholder="Stage1st 用户 ID" />'
          '<button>获取画像</button>'
          '<textarea>结果会显示在这里。</textarea>'
          '<select><option>deepseek-v4-pro</option></select>';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, contains('摸鱼模式'));
      expect(parsed, isNot(contains('<input')));
      expect(parsed, isNot(contains('<button')));
      expect(parsed, isNot(contains('<textarea')));
      expect(parsed, isNot(contains('<select')));
    });
  });

  group('br and newline normalization', () {
    test('normalizes Discuz HTML single line break <br />\\r\\n to single <br/>', () {
      const input = 'Line 1<br />\r\n- Line 2<br />\r\n- Line 3';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, equals('Line 1<br/>- Line 2<br/>- Line 3'));
    });

    test('preserves Discuz HTML double line break <br />\\r\\n<br />\\r\\n as double <br/>', () {
      const input = 'Paragraph 1<br />\r\n<br />\r\nParagraph 2';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, equals('Paragraph 1<br/><br/>Paragraph 2'));
    });

    test('normalizes plain text single \\n to single <br/>', () {
      const input = 'Line 1\n- Line 2\n- Line 3';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, equals('Line 1<br/>- Line 2<br/>- Line 3'));
    });

    test('normalizes plain text double \\n\\n to double <br/>', () {
      const input = 'Paragraph 1\n\nParagraph 2';
      final parsed = BbcodeParser.parse(input);
      expect(parsed, equals('Paragraph 1<br/><br/>Paragraph 2'));
    });
  });
}
