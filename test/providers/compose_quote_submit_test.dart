import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/quote_info.dart';
import 'package:s1er/providers/compose_provider.dart';

void main() {
  group('ComposeController.quoteInfoForSubmit', () {
    const official = QuoteInfo(
      noticeAuthor: 'd755encoded',
      noticeTrimStr:
          '[post][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]a[/url][/post]',
    );

    final quoted = Post(
      pid: '42',
      message: 'quoted body',
      author: 'alice',
      authorId: '7',
      dateline: 1704067200,
      floor: 3,
    );

    test('returns null when no quoteInfo', () {
      expect(
        ComposeController.quoteInfoForSubmit(
          quoteInfo: null,
          quotedPost: quoted,
          tid: '100',
        ),
        isNull,
      );
    });

    test('keeps official trim when no quoted Post', () {
      final out = ComposeController.quoteInfoForSubmit(
        quoteInfo: official,
        tid: '100',
      );
      expect(out, same(official));
      expect(out!.noticeTrimStr, contains('[post]'));
    });

    test('replaces trim with full QuoteBuilder BBCode when Post given', () {
      final out = ComposeController.quoteInfoForSubmit(
        quoteInfo: official,
        quotedPost: quoted,
        tid: '100',
      )!;
      expect(out.noticeAuthor, 'd755encoded');
      expect(out.noticeTrimStr, contains('[quote]'));
      expect(out.noticeTrimStr, isNot(contains('[post]')));
      expect(out.noticeTrimStr, contains('pid=42'));
      expect(out.noticeTrimStr, contains('ptid=100'));
      expect(out.noticeTrimStr, contains('alice'));
      expect(out.noticeTrimStr, contains('quoted body'));
      expect(out.submitNoticeTrimStr, out.noticeTrimStr);
    });
  });
}
