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
}
