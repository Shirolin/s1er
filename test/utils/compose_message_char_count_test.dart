import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/compose_message_char_count.dart';

void main() {
  group('composeMessageCharCount', () {
    test('counts grapheme clusters', () {
      expect(composeMessageCharCount('你好', stripMediaPlaceholders: false), 2);
      expect(composeMessageCharCount('abc', stripMediaPlaceholders: false), 3);
    });

    test('strips media placeholders when requested', () {
      const text = '前⟦图1⟧后';
      expect(
        composeMessageCharCount(text, stripMediaPlaceholders: false),
        greaterThan(2),
      );
      expect(composeMessageCharCount(text, stripMediaPlaceholders: true), 2);
    });
  });
}
