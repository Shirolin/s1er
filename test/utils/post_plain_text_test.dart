import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/post_plain_text.dart';

void main() {
  group('PostPlainText.fromMessage', () {
    test('returns empty for blank input', () {
      expect(PostPlainText.fromMessage(''), isEmpty);
      expect(PostPlainText.fromMessage('   '), isEmpty);
    });

    test('strips bbcode formatting and keeps text', () {
      expect(
        PostPlainText.fromMessage('[b]hello[/b] [i]world[/i]'),
        'hello world',
      );
    });

    test('preserves newlines from line breaks', () {
      final plain = PostPlainText.fromMessage('line1\nline2\n\nline3');
      expect(plain, contains('line1'));
      expect(plain, contains('line2'));
      expect(plain, contains('line3'));
      expect(plain.split('\n').length, greaterThanOrEqualTo(3));
    });

    test('keeps link label text', () {
      expect(
        PostPlainText.fromMessage('[url=https://example.com]click me[/url]'),
        'click me',
      );
    });

    test('decodes html entities', () {
      expect(
        PostPlainText.fromMessage('A &amp; B &quot;C&quot;'),
        'A & B "C"',
      );
    });

    test('keeps quoted body text', () {
      final plain = PostPlainText.fromMessage(
        '[quote]quoted bit[/quote]\nafter quote',
      );
      expect(plain, contains('quoted bit'));
      expect(plain, contains('after quote'));
    });

    test('emits image url for img bbcode', () {
      final plain = PostPlainText.fromMessage(
        'pic [img]https://example.com/a.jpg[/img] end',
      );
      expect(plain, contains('https://example.com/a.jpg'));
      expect(plain, contains('pic'));
      expect(plain, contains('end'));
    });

    test('emits emoticon code', () {
      final plain = PostPlainText.fromMessage('hi [f:001]');
      expect(plain, contains('hi'));
      expect(plain, contains('[f:001]'));
    });

    test('handles mixed html fragments', () {
      final plain = PostPlainText.fromMessage(
        '<b>bold</b><br/>second &quot;line&quot;',
      );
      expect(plain, contains('bold'));
      expect(plain, contains('second "line"'));
    });
  });
}
