import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/compose_img_tags.dart';

void main() {
  group('compose_img_tags', () {
    test('extractImgUrls preserves first-seen order and dedupes', () {
      const text =
          'a[img]https://a/1.png[/img]b[img]https://a/2.png[/img]'
          '[img]https://a/1.png[/img]';
      expect(extractImgUrls(text), [
        'https://a/1.png',
        'https://a/2.png',
      ]);
    });

    test('removeImgTag strips all matching tags', () {
      const text =
          '[img]https://x/long-file-name.webp[/img] hi '
          '[img]https://x/long-file-name.webp[/img]';
      expect(
        removeImgTag(text, 'https://x/long-file-name.webp').trim(),
        'hi',
      );
    });

    test('displayLabelForIndex is short', () {
      expect(displayLabelForIndex(0), '图片 1');
      expect(displayLabelForIndex(11), '图片 12');
    });

    test('filenameFromUrl uses last path segment', () {
      expect(
        filenameFromUrl('https://p.sda1.dev/33/abc/测试.webp'),
        '测试.webp',
      );
      expect(
        filenameFromUrl(
          'https://p.sda1.dev/33/abc/QQ截图20260714142502.webp',
        ),
        'QQ截图20260714142502.webp',
      );
    });

    test('insertImgTagAt pads around neighbors', () {
      final result = insertImgTagAt(
        text: '你好世界',
        start: 2,
        end: 2,
        url: 'https://a/x.png',
      );
      expect(result.text, contains(' [img]https://a/x.png[/img] '));
    });

    test('insertEmoticonEntity adds trailing space before CJK', () {
      final result = insertEmoticonEntity(
        text: '有动森',
        start: 0,
        end: 0,
        entity: '[f:057]',
      );
      expect(result.text, startsWith('[f:057] '));
      expect(result.text, contains('有动森'));
    });

    test('pushRecentEmoticon moves to front and caps at max', () {
      final list = pushRecentEmoticon(
        ['[f:001]', '[f:002]'],
        '[f:002]',
        max: 2,
      );
      expect(list, ['[f:002]', '[f:001]']);
      final capped = pushRecentEmoticon(
        List.generate(24, (i) => '[f:${(i + 1).toString().padLeft(3, '0')}]'),
        '[f:099]',
        max: 24,
      );
      expect(capped.first, '[f:099]');
      expect(capped.length, 24);
    });
  });
}
