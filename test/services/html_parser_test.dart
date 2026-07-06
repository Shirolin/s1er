import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/bbcode_parser.dart';
import 'package:s1_app/services/html_parser_service.dart';

void main() {
  group('BbcodeParser', () {
    test('converts bold tags', () {
      final result = BbcodeParser.parse('[b]hello[/b]');
      expect(result, contains('<b>hello</b>'));
    });

    test('converts italic tags', () {
      final result = BbcodeParser.parse('[i]italic text[/i]');
      expect(result, contains('<i>italic text</i>'));
    });

    test('converts underline tags', () {
      final result = BbcodeParser.parse('[u]underlined[/u]');
      expect(result, contains('<u>underlined</u>'));
    });

    test('converts strikethrough tags', () {
      final result = BbcodeParser.parse('[s]strikethrough[/s]');
      expect(result, contains('<s>strikethrough</s>'));
    });

    test('converts image tags', () {
      final result =
          BbcodeParser.parse('[img]https://example.com/pic.jpg[/img]');
      expect(result, contains('img'));
      expect(result, contains('https://example.com/pic.jpg'));
    });

    test('converts quote tags', () {
      final result = BbcodeParser.parse('[quote]quoted text[/quote]');
      expect(result, contains('<blockquote>quoted text</blockquote>'));
    });

    test('converts code tags', () {
      final result = BbcodeParser.parse('[code]var x = 1;[/code]');
      expect(result, contains('<pre>var x = 1;</pre>'));
    });

    test('converts URL tags', () {
      final result =
          BbcodeParser.parse('[url=https://example.com]link[/url]');
      expect(result, contains('<a href="https://example.com">link</a>'));
    });

    test('converts simple URL tags', () {
      final result = BbcodeParser.parse('[url]https://example.com[/url]');
      expect(result, contains('<a href="https://example.com">'));
    });

    test('converts color tags', () {
      final result = BbcodeParser.parse('[color=red]colored text[/color]');
      expect(result, contains('color:red'));
      expect(result, contains('colored text'));
    });

    test('converts size tags', () {
      final result = BbcodeParser.parse('[size=20]big text[/size]');
      expect(result, contains('font-size:20px'));
      expect(result, contains('big text'));
    });

    test('converts emoticon codes', () {
      final result = BbcodeParser.parse('[f:001]');
      expect(result, contains('emoticon'));
    });

    test('handles nested tags', () {
      final result = BbcodeParser.parse('[b][i]bold and italic[/i][/b]');
      expect(result, contains('bold and italic'));
    });

    test('escapes HTML entities in plain text', () {
      final result = BbcodeParser.parse('a < b & c > d');
      expect(result, contains('&lt;'));
      expect(result, contains('&amp;'));
      expect(result, contains('&gt;'));
    });

    test('handles empty input', () {
      final result = BbcodeParser.parse('');
      expect(result, isEmpty);
    });

    test('converts list items', () {
      final result = BbcodeParser.parse('[*]item1\n[*]item2');
      expect(result, contains('<li>'));
    });

    test('converts newlines to br', () {
      final result = BbcodeParser.parse('line1\nline2');
      expect(result, contains('<br>'));
    });

    test('extractImages extracts image URLs', () {
      final html =
          '<p>text <img src="https://example.com/a.jpg" /> more <img src="https://example.com/b.png" /></p>';
      final images = BbcodeParser.extractImages(html);
      expect(images.length, 2);
      expect(images[0], 'https://example.com/a.jpg');
      expect(images[1], 'https://example.com/b.png');
    });

    test('stripTags removes HTML tags', () {
      final text = BbcodeParser.stripTags('<b>hello</b> <i>world</i>');
      expect(text, 'hello world');
    });

    test('stripTags handles nested tags', () {
      final text =
          BbcodeParser.stripTags('<div><span class="x">content</span></div>');
      expect(text, 'content');
    });
  });

  group('HtmlParserService - Thread List Parsing', () {
    test('parses thread list from Discuz HTML', () {
      final html = '''
        <div id="threadlist">
          <ul>
            <li id="normalthread_123" class="normalthread">
              <h2><a href="thread-123-1-1.html">Test Thread Subject</a></h2>
              <td class="by"><cite>testuser</cite></td>
              <td class="num"><a>500</a><em>20</em></td>
            </li>
          </ul>
        </div>
      ''';
      final threads = HtmlParserService.parseThreadListHtml(html, fid: '4');
      expect(threads.length, 1);
      expect(threads[0].tid, '123');
      expect(threads[0].subject, 'Test Thread Subject');
      expect(threads[0].fid, '4');
    });

    test('parses multiple threads', () {
      final html = '''
        <div id="threadlist">
          <ul>
            <li id="normalthread_100" class="normalthread">
              <h2><a href="thread-100-1-1.html">First Thread</a></h2>
              <td class="by"><cite>user1</cite></td>
            </li>
            <li id="normalthread_200" class="normalthread">
              <h2><a href="thread-200-1-1.html">Second Thread</a></h2>
              <td class="by"><cite>user2</cite></td>
            </li>
          </ul>
        </div>
      ''';
      final threads = HtmlParserService.parseThreadListHtml(html, fid: '5');
      expect(threads.length, 2);
      expect(threads[0].tid, '100');
      expect(threads[0].subject, 'First Thread');
      expect(threads[1].tid, '200');
      expect(threads[1].subject, 'Second Thread');
    });

    test('returns empty list for invalid HTML', () {
      final threads = HtmlParserService.parseThreadListHtml(
        '<html><body>nothing here</body></html>',
        fid: '1',
      );
      expect(threads, isEmpty);
    });

    test('handles missing author gracefully', () {
      final html = '''
        <div id="threadlist">
          <ul>
            <li id="normalthread_999" class="normalthread">
              <h2><a href="thread-999-1-1.html">No Author Thread</a></h2>
            </li>
          </ul>
        </div>
      ''';
      final threads = HtmlParserService.parseThreadListHtml(html, fid: '1');
      expect(threads.length, 1);
      expect(threads[0].author, '');
    });
  });

  group('HtmlParserService - Post List Parsing', () {
    test('parses posts from thread HTML', () {
      final html = '''
        <div id="postlist">
          <div id="post_1001" class="plhin">
            <div class="pi">
              <a href="space-uid-100.html" class="xw1">alice</a>
            </div>
            <div class="message">
              Hello world, this is my post!
            </div>
          </div>
          <div id="post_1002" class="plhin">
            <div class="pi">
              <a href="space-uid-200.html" class="xw1">bob</a>
            </div>
            <div class="message">
              Reply from bob
            </div>
          </div>
        </div>
      ''';
      final posts = HtmlParserService.parsePostListHtml(html);
      expect(posts.length, 2);
      expect(posts[0].author, 'alice');
      expect(posts[0].message, contains('Hello world'));
      expect(posts[0].floor, 1);
      expect(posts[1].author, 'bob');
      expect(posts[1].floor, 2);
    });

    test('returns empty list for no posts', () {
      final posts = HtmlParserService.parsePostListHtml(
        '<html><body>no posts</body></html>',
      );
      expect(posts, isEmpty);
    });
  });

  group('HtmlParserService - Formhash Extraction', () {
    test('extracts formhash from HTML', () {
      final html = '''
        <html><body>
          <form>
            <input type="hidden" name="formhash" value="abc123def456" />
          </form>
        </body></html>
      ''';
      final formhash = HtmlParserService.extractFormhash(html);
      expect(formhash, 'abc123def456');
    });

    test('returns empty string when formhash not found', () {
      final html = '<html><body>no form here</body></html>';
      final formhash = HtmlParserService.extractFormhash(html);
      expect(formhash, '');
    });
  });
}
