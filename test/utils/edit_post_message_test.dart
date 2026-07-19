import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/utils/edit_post_message.dart';
import 'package:s1er/utils/post_signature.dart';

void main() {
  const quote =
      '[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]'
      '作者[/url] 发表于 07-19 14:32[/size]\n'
      '被引用内容\n'
      '[/quote]';

  final signature = PostSignature.build(
    enabled: true,
    showDevice: true,
    custom: '有点困',
    deviceLabel: 'Pixel 7a',
  );

  test('strips leading quote and trailing client signature', () {
    final raw = '$quote\npdd叠券能到260+\n\n$signature';
    final parts = EditPostMessageParts.split(raw);
    expect(parts.hasLeadingQuote, isTrue);
    expect(parts.leadingQuote, quote);
    expect(parts.body, 'pdd叠券能到260+');
    expect(parts.hadClientSignature, isTrue);
    expect(parts.quoteInner, contains('被引用内容'));
    expect(parts.quoteInner, isNot(contains('[quote]')));
  });

  test('compose restores quote before body without signature', () {
    final out = EditPostMessageParts.compose(
      leadingQuote: quote,
      body: '新正文',
    );
    expect(out, startsWith('[quote]'));
    expect(out, endsWith('新正文'));
    expect(out, isNot(contains('S1er 客户端')));
  });

  test('body-only message stays unchanged', () {
    final parts = EditPostMessageParts.split('只有正文');
    expect(parts.hasLeadingQuote, isFalse);
    expect(parts.body, '只有正文');
    expect(parts.hadClientSignature, isFalse);
  });

  test('PostSignature.stripTrailing removes colophon only', () {
    final raw = '正文\n\n$signature';
    expect(PostSignature.hasTrailing(raw), isTrue);
    expect(PostSignature.stripTrailing(raw), '正文');
    expect(
      PostSignature.stripTrailing('正文无尾巴'),
      '正文无尾巴',
    );
    expect(
      PostSignature.stripTrailing(raw),
      isNot(contains(S1Constants.appName)),
    );
  });
}
