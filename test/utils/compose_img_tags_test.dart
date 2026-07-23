import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/compose_img_tags.dart';

void main() {
  group('compose_img_tags', () {
    test('extractImgUrls preserves first-seen order and dedupes', () {
      const text = 'a[img]https://a/1.png[/img]b[img]https://a/2.png[/img]'
          '[img]https://a/1.png[/img]';
      expect(extractImgUrls(text), [
        'https://a/1.png',
        'https://a/2.png',
      ]);
    });

    test('removeImgTag strips all matching tags', () {
      const text = '[img]https://x/long-file-name.webp[/img] hi '
          '[img]https://x/long-file-name.webp[/img]';
      expect(
        removeImgTag(text, 'https://x/long-file-name.webp').trim(),
        'hi',
      );
    });

    test('removeMediaTag strips attachimg by exact tag', () {
      const text = '前[attachimg]12[/attachimg]后';
      expect(removeMediaTag(text, '[attachimg]12[/attachimg]'), '前后');
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

    test('splitComposeMedia pulls img and attach tags out of body', () {
      const raw = '看图 [img]https://p.sda1.dev/a.png[/img]\n'
          '还有 [attachimg]12[/attachimg] 和 [attach]34[/attach]';
      final split = splitComposeMedia(raw);
      expect(split.body, '看图\n还有 和');
      expect(split.media.map((m) => m.tag), [
        '[img]https://p.sda1.dev/a.png[/img]',
        '[attachimg]12[/attachimg]',
        '[attach]34[/attach]',
      ]);
      expect(split.media.first.previewUrl, 'https://p.sda1.dev/a.png');
      expect(split.media[1].previewUrl, isNull);
      expect(split.media[1].label, '论坛图片 · 12');
      expect(split.media[1].isAttachimg, isTrue);
      expect(split.media[2].label, '论坛附件 · 34');
      expect(split.media[2].isForumAttach, isTrue);
    });

    test('appendComposeMedia joins tags after body', () {
      expect(
        appendComposeMedia('正文', [
          '[img]https://a/1.png[/img]',
          '[attachimg]9[/attachimg]',
        ]),
        '正文\n\n[img]https://a/1.png[/img]\n[attachimg]9[/attachimg]',
      );
      expect(
        appendComposeMedia('  ', ['[img]https://a/1.png[/img]']),
        '[img]https://a/1.png[/img]',
      );
    });

    test('extractAttachImageUrls maps aimg id to full href', () {
      const html =
          '<div class="img"><a href="https://img.stage1st.com/forum/a.png" '
          'target="_blank"><img id="aimg_2098060" '
          'src="https://img.stage1st.com/forum/a.png.thumb.jpg" /></a></div>';
      expect(
        extractAttachImageUrls(html),
        {'2098060': 'https://img.stage1st.com/forum/a.png'},
      );
    });

    test('rewriteAttachimgForPreview swaps known aids', () {
      const raw = '文\n[attachimg]2098060[/attachimg]\n[attachimg]1[/attachimg]';
      expect(
        rewriteAttachimgForPreview(raw, {
          '2098060': 'https://img.stage1st.com/forum/a.png',
        }),
        '文\n[img]https://img.stage1st.com/forum/a.png[/img]\n'
        '[attachimg]1[/attachimg]',
      );
      expect(
        hasUnresolvedAttachimg(
          rewriteAttachimgForPreview(raw, {
            '2098060': 'https://img.stage1st.com/forum/a.png',
          }),
        ),
        isTrue,
      );
      expect(
        hasUnresolvedAttachimg(
          rewriteAttachimgForPreview(raw, {
            '2098060': 'https://img.stage1st.com/forum/a.png',
            '1': 'https://img.stage1st.com/forum/b.png',
          }),
        ),
        isFalse,
      );
    });

    test('attachimgFallbackLabel includes aid', () {
      expect(attachimgFallbackLabel('12', index: 1), '论坛图片 · 12');
      expect(attachimgFallbackLabel('  ', index: 2), '论坛图片 2');
    });

    test('splitComposeMedia uses attachImageUrls for previewUrl', () {
      final split = splitComposeMedia(
        '[attachimg]12[/attachimg]',
        attachImageUrls: {'12': 'https://img.stage1st.com/x.png'},
      );
      expect(split.media.single.previewUrl, 'https://img.stage1st.com/x.png');
      expect(split.media.single.label, 'x.png');
    });
  });

  group('compose media placeholders', () {
    test('split keeps layout with placeholders', () {
      final split = splitComposeMediaWithPlaceholders(
        '前[img]https://a.test/1.png[/img]中'
        '[attachimg]9[/attachimg]后',
        attachImageUrls: {'9': 'https://a.test/9.png'},
      );
      expect(split.body, '前⟦图1⟧中⟦图2⟧后');
      expect(split.media.map((m) => m.tag).toList(), [
        '[img]https://a.test/1.png[/img]',
        '[attachimg]9[/attachimg]',
      ]);
      expect(split.effectiveSlots, [1, 2]);
    });

    test('expand restores by slot not list order', () {
      const body = 'A⟦图2⟧B⟦图1⟧C';
      final expanded = expandComposeMediaPlaceholders(body, {
        1: '[img]https://a.test/1.png[/img]',
        2: '[img]https://a.test/2.png[/img]',
      });
      expect(
        expanded,
        'A[img]https://a.test/2.png[/img]B[img]https://a.test/1.png[/img]C',
      );
    });

    test('expand appends unused tags at end', () {
      final expanded = expandComposeMediaPlaceholders('只看⟦图1⟧', {
        1: '[img]https://a.test/1.png[/img]',
        2: '[img]https://a.test/2.png[/img]',
      });
      expect(
        expanded,
        '只看[img]https://a.test/1.png[/img]\n\n'
        '[img]https://a.test/2.png[/img]',
      );
    });

    test('remove and strip placeholders', () {
      expect(
        removeComposeMediaPlaceholder('前⟦图1⟧中⟦图2⟧后', 1),
        '前中⟦图2⟧后',
      );
      expect(stripComposeMediaPlaceholders('文⟦图1⟧本'), '文本');
    });
  });
}
