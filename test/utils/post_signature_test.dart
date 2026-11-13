import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/utils/post_signature.dart';

void main() {
  group('PostSignature.sanitizeCustom', () {
    test('trims and strips brackets and newlines', () {
      expect(
        PostSignature.sanitizeCustom('  今日[宜]摸鱼\n第二行  '),
        '今日宜摸鱼 第二行',
      );
    });

    test('truncates to maxCustomLength', () {
      const long = '一二三四五六七八九十一二三四五六七八九十超额';
      final out = PostSignature.sanitizeCustom(long);
      expect(out.length, PostSignature.maxCustomLength);
      expect(out, '一二三四五六七八九十一二三四五六七八九十');
    });
  });

  group('PostSignature.build', () {
    test('returns empty when disabled', () {
      expect(
        PostSignature.build(
          enabled: false,
          showDevice: true,
          custom: 'hi',
          deviceLabel: 'Pixel 8',
        ),
        '',
      );
    });

    test('custom + device uses dash colophon', () {
      expect(
        PostSignature.build(
          enabled: true,
          showDevice: true,
          custom: '今日宜摸鱼',
          deviceLabel: 'Pixel 8',
        ),
        '[size=1][color=gray]——今日宜摸鱼 · 来自 Pixel 8 上的 '
        '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
      );
    });

    test('no custom + device', () {
      expect(
        PostSignature.build(
          enabled: true,
          showDevice: true,
          custom: '',
          deviceLabel: 'Android',
        ),
        '[size=1][color=gray]——来自 Android 上的 '
        '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
      );
    });

    test('custom without device', () {
      expect(
        PostSignature.build(
          enabled: true,
          showDevice: false,
          custom: '摸鱼',
          deviceLabel: 'Pixel 8',
        ),
        '[size=1][color=gray]——摸鱼 · 来自 '
        '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
      );
    });

    test('showDevice but empty label omits device part', () {
      expect(
        PostSignature.build(
          enabled: true,
          showDevice: true,
          custom: '',
          deviceLabel: '  ',
        ),
        '[size=1][color=gray]——来自 '
        '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
      );
    });

    test('buildDisplay strips bbcode for settings preview', () {
      expect(
        PostSignature.buildDisplay(
          enabled: true,
          showDevice: true,
          custom: '摸鱼',
          deviceLabel: 'Pixel 8',
        ),
        '——摸鱼 · 来自 Pixel 8 上的 S1er 客户端',
      );
    });
  });

  group('PostSignature.appendIfEnabled', () {
    test('appends with blank line', () {
      final out = PostSignature.appendIfEnabled(
        '正文内容',
        enabled: true,
        showDevice: true,
        custom: '',
        deviceLabel: 'iPhone',
      );
      expect(
        out,
        '正文内容\n\n'
        '[size=1][color=gray]——来自 iPhone 上的 '
        '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
      );
    });

    test('disabled leaves body only', () {
      expect(
        PostSignature.appendIfEnabled(
          '正文  ',
          enabled: false,
          showDevice: true,
          custom: 'x',
          deviceLabel: 'Android',
        ),
        '正文',
      );
    });
  });

  group('PostSignature.extractForShare', () {
    test('dedupes S1er client suffix while keeping device and custom', () {
      final deviceOnly = PostSignature.appendIfEnabled(
        '这是正文第一段',
        enabled: true,
        showDevice: true,
        custom: '',
        deviceLabel: 'iPhone',
      );
      expect(
        PostSignature.extractForShare(deviceOnly),
        (body: '这是正文第一段', signature: '——来自 iPhone'),
      );

      final customAndDevice = PostSignature.appendIfEnabled(
        '正文',
        enabled: true,
        showDevice: true,
        custom: '摸鱼',
        deviceLabel: 'Pixel 8',
      );
      expect(
        PostSignature.extractForShare(customAndDevice),
        (body: '正文', signature: '——摸鱼 · 来自 Pixel 8'),
      );

      final customOnly = PostSignature.appendIfEnabled(
        '正文',
        enabled: true,
        showDevice: false,
        custom: '摸鱼',
      );
      expect(
        PostSignature.extractForShare(customOnly),
        (body: '正文', signature: '——摸鱼'),
      );

      final defaultOnly = PostSignature.appendIfEnabled(
        '正文',
        enabled: true,
        showDevice: false,
        custom: '',
      );
      expect(
        PostSignature.extractForShare(defaultOnly),
        (body: '正文', signature: null),
      );
    });

    test('extracts third-party client trailing colophon', () {
      const raw = '正文内容\n\n[size=1][color=Gray]——来自论坛助手,iPhone[/color][/size]';
      final extracted = PostSignature.extractForShare(raw);
      expect(extracted.body, '正文内容');
      expect(extracted.signature, '——来自论坛助手,iPhone');

      const wrappedByUrl =
          '正文内容\n\n[url=https://bbs.saraba1st.com/2b/thread-2029836-1-1.html]'
          '[color=Gray]——来自论坛助手,iPhone[/color][/url]';
      final extractedUrl = PostSignature.extractForShare(wrappedByUrl);
      expect(extractedUrl.body, '正文内容');
      expect(extractedUrl.signature, '——来自论坛助手,iPhone');
    });

    test('does not strip literary attribution without client/device keyword',
        () {
      const raw = '地上本没有路，走的人多了，也便成了路。\n\n——来自鲁迅';
      final extracted = PostSignature.extractForShare(raw);
      expect(extracted.body, raw);
      expect(extracted.signature, isNull);
    });

    test('keeps message untouched when body would become empty', () {
      final sigOnly = PostSignature.build(
        enabled: true,
        showDevice: false,
        custom: '',
      );
      final extracted = PostSignature.extractForShare(sigOnly);
      expect(extracted.body, sigOnly);
      expect(extracted.signature, isNull);
    });

    test('extracts Discuz HTML signatures such as S1Fun and S1er', () {
      const s1FunHtml =
          '<blockquote>引用</blockquote>11.18? 我记得这是第一波非抽选的抢票吧?'
          '<br />\r\n<br />\r\n—— 来自 '
          '<a href="https://stage1st.com/2b/thread-2219310-1-1.html" '
          'target="_blank">S1Fun</a>';
      final fun = PostSignature.extractForShare(s1FunHtml);
      expect(
        fun.body,
        '<blockquote>引用</blockquote>11.18? 我记得这是第一波非抽选的抢票吧?',
      );
      expect(fun.signature, '—— 来自 S1Fun');

      const s1erHtml =
          '正文内容<br />\n<font size="1"><font color="gray">——来自 Pixel 8 上的 '
          '<a href="https://github.com/Shirolin/s1er" target="_blank">'
          'S1er 客户端</a></font></font>';
      final s1er = PostSignature.extractForShare(s1erHtml);
      expect(s1er.body, '正文内容');
      expect(s1er.signature, '——来自 Pixel 8');

      const literaryHtml = '地上本没有路。<br />\n<br />\n——来自鲁迅';
      final lit = PostSignature.extractForShare(literaryHtml);
      expect(lit.body, literaryHtml);
      expect(lit.signature, isNull);
    });
  });
}
