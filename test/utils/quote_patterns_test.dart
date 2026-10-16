import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/quote_patterns.dart';

/// 锁定 [QuotePatterns] 各变体的**有意差异**：集中模式的同时，明确哪些
/// 变体行为不同（避免将来被误认为重复而合并）。
void main() {
  group('bbcodeBody', () {
    test('matches non-greedy quote body with capture', () {
      const input = 'a [quote]body[/quote] b [quote]two[/quote]';
      final matches = QuotePatterns.bbcodeBody.allMatches(input).toList();
      expect(matches, hasLength(2));
      expect(matches.first.group(1), 'body');
      expect(matches.last.group(1), 'two');
    });
  });

  group('headerStrict vs headerLoose', () {
    const validHeader =
        '[size=2][url=x]alice[/url] 发表于 2024-07-19 14:32[/size]\nbody';

    test('strict matches a valid header and captures the author', () {
      final m = QuotePatterns.headerStrict.firstMatch(validHeader);
      expect(m, isNotNull);
      expect(m!.group(1), 'alice');
    });

    test('both match a valid header', () {
      expect(QuotePatterns.headerStrict.firstMatch(validHeader), isNotNull);
      expect(QuotePatterns.headerLoose.firstMatch(validHeader), isNotNull);
    });

    test('loose matches a malformed dateline that strict rejects', () {
      const malformed = '[size=2][url=x]alice[/url] 发表于 某天某时[/size]\nbody';
      expect(QuotePatterns.headerStrict.firstMatch(malformed), isNull);
      expect(QuotePatterns.headerLoose.firstMatch(malformed), isNotNull);
    });
  });

  group('html reply wrap variants', () {
    test('htmlReplyWrap matches only div.reply_wrap', () {
      const divInput = '<div class="reply_wrap">x</div>';
      const quoteInput = '<blockquote>y</blockquote>';
      expect(QuotePatterns.htmlReplyWrap.hasMatch(divInput), isTrue);
      expect(QuotePatterns.htmlReplyWrap.hasMatch(quoteInput), isFalse);
    });

    test('htmlQuoteBlock matches both div.reply_wrap and blockquote', () {
      const divInput = '<div class="reply_wrap">x</div>';
      const quoteInput = '<blockquote>y</blockquote>';
      expect(QuotePatterns.htmlQuoteBlock.hasMatch(divInput), isTrue);
      expect(QuotePatterns.htmlQuoteBlock.hasMatch(quoteInput), isTrue);
      expect(
        QuotePatterns.htmlQuoteBlock.firstMatch(quoteInput)!.group(1),
        'y',
      );
    });
  });
}
