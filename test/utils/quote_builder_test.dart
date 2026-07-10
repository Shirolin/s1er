import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/utils/quote_builder.dart';

void main() {
  final samplePost = Post(
    pid: '999',
    message: 'Hello world',
    author: 'tester',
    authorId: '1',
    dateline: 1704067200, // 2024-01-01 08:00 UTC+8 approx - depends on locale
    floor: 2,
  );

  group('QuoteBuilder', () {
    test('buildQuoteBbcode includes author, pid and tid', () {
      final quote = QuoteBuilder.buildQuoteBbcode(
        post: samplePost,
        tid: '456',
      );

      expect(quote, contains('[quote]'));
      expect(quote, contains('[/quote]'));
      expect(quote, contains('pid=999'));
      expect(quote, contains('ptid=456'));
      expect(quote, contains('tester'));
      expect(quote, contains('Hello world'));
    });

    test('stripNestedQuotes removes quote blocks', () {
      const input = 'before [quote]nested[/quote] after';
      expect(QuoteBuilder.stripNestedQuotes(input), 'before  after');
    });

    test('stripNestedQuotes removes reply_wrap divs', () {
      const input =
          'text <div class="reply_wrap"><a>user</a>body</div> tail';
      expect(QuoteBuilder.stripNestedQuotes(input), 'text  tail');
    });

    test('stripHtmlTags removes tags and decodes entities', () {
      const input = '<b>bold</b> &amp; plain';
      expect(QuoteBuilder.stripHtmlTags(input), 'bold & plain');
    });

    test('buildMessageWithQuote prepends quote before user text', () {
      final message = QuoteBuilder.buildMessageWithQuote(
        post: samplePost,
        tid: '456',
        userText: 'my reply',
      );

      expect(message, startsWith('[quote]'));
      expect(message, endsWith('my reply'));
    });

    test('buildMessageWithQuote without quote returns trimmed user text', () {
      final message = QuoteBuilder.buildMessageWithQuote(
        post: samplePost,
        tid: '456',
        userText: '  only me  ',
        includeQuote: false,
      );

      expect(message, 'only me');
      expect(message, isNot(contains('[quote]')));
    });

    test('previewText strips quotes and html then truncates', () {
      final input = '[quote]old[/quote]<b>visible</b> ${'x' * 200}';
      final preview = QuoteBuilder.previewText(input, maxLength: 20);
      expect(preview, isNot(contains('[quote]')));
      expect(preview.length, lessThanOrEqualTo(21));
    });
  });
}
