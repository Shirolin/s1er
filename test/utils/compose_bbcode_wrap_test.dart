import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/compose_bbcode_wrap.dart';

void main() {
  group('wrapBbcodeSelection', () {
    test('wraps non-empty selection and places cursor after close tag', () {
      final result = wrapBbcodeSelection(
        text: 'hello world',
        start: 0,
        end: 5,
        openTag: '[b]',
        closeTag: '[/b]',
      );
      expect(result.text, '[b]hello[/b] world');
      expect(result.cursor, '[b]hello[/b]'.length);
    });

    test('inserts empty tag pair and places cursor between tags', () {
      final result = wrapBbcodeSelection(
        text: 'ab',
        start: 1,
        end: 1,
        openTag: '[i]',
        closeTag: '[/i]',
      );
      expect(result.text, 'a[i][/i]b');
      expect(result.cursor, 'a[i]'.length);
    });

    test('clamps out-of-range selection', () {
      final result = wrapBbcodeSelection(
        text: 'hi',
        start: -3,
        end: 99,
        openTag: '[s]',
        closeTag: '[/s]',
      );
      expect(result.text, '[s]hi[/s]');
      expect(result.cursor, '[s]hi[/s]'.length);
    });

    test('supports url= open tag with selection', () {
      final result = wrapBbcodeSelection(
        text: 'click',
        start: 0,
        end: 5,
        openTag: '[url=https://s1er.app]',
        closeTag: '[/url]',
      );
      expect(result.text, '[url=https://s1er.app]click[/url]');
      expect(result.cursor, result.text.length);
    });

    test('supports url= open tag with empty selection', () {
      final result = wrapBbcodeSelection(
        text: '',
        start: 0,
        end: 0,
        openTag: '[url=https://s1er.app]',
        closeTag: '[/url]',
      );
      expect(result.text, '[url=https://s1er.app][/url]');
      expect(result.cursor, '[url=https://s1er.app]'.length);
    });

    test('does not pad whitespace around neighbors', () {
      final result = wrapBbcodeSelection(
        text: '你好世界',
        start: 1,
        end: 3,
        openTag: '[b]',
        closeTag: '[/b]',
      );
      expect(result.text, '你[b]好世[/b]界');
    });
  });
}
