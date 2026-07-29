import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/read_perm_options.dart';

void main() {
  group('normalizeReadPermValue', () {
    test('maps empty and zero to unlimited', () {
      expect(normalizeReadPermValue(''), '');
      expect(normalizeReadPermValue('0'), '');
      expect(normalizeReadPermValue(' 0 '), '');
    });

    test('keeps positive thresholds', () {
      expect(normalizeReadPermValue('1'), '1');
      expect(normalizeReadPermValue(' 100 '), '100');
    });
  });

  group('mergeReadPermOptions', () {
    test('includes unlimited option from empty value', () {
      final merged = mergeReadPermOptions([
        (value: '', label: '不限'),
        (value: '10', label: '游客'),
      ]);

      expect(merged, {'': '不限', '10': '游客'});
    });

    test('merges duplicate values with slash-separated labels', () {
      final merged = mergeReadPermOptions([
        (value: '1', label: 'YYY组'),
        (value: '1', label: 'QQ游客'),
        (value: '1', label: '抹布'),
      ]);

      expect(merged['1'], 'YYY组 / QQ游客 / 抹布');
    });

    test('skips duplicate labels for the same value', () {
      final merged = mergeReadPermOptions([
        (value: '1', label: '萌新'),
        (value: '1', label: '萌新'),
      ]);

      expect(merged['1'], '萌新');
    });

    test('falls back to threshold label when option text is empty', () {
      final merged = mergeReadPermOptions([
        (value: '20', label: ''),
      ]);

      expect(merged['20'], '≥ 20');
    });

    test('preserves document order', () {
      final merged = mergeReadPermOptions([
        (value: '', label: '不限'),
        (value: '1', label: 'A'),
        (value: '10', label: 'B'),
        (value: '20', label: 'C'),
      ]);

      expect(merged.keys.toList(), ['', '1', '10', '20']);
    });

    test('normalizes zero value to unlimited', () {
      final merged = mergeReadPermOptions([
        (value: '0', label: '不限'),
        (value: '1', label: '组A'),
      ]);

      expect(merged, {'': '不限', '1': '组A'});
    });
  });

  group('normalizeSelectedReadPerm', () {
    test('normalizes draft unlimited values', () {
      expect(normalizeSelectedReadPerm('0'), '');
      expect(normalizeSelectedReadPerm(''), '');
      expect(normalizeSelectedReadPerm('100'), '100');
      expect(normalizeSelectedReadPerm(null), isNull);
    });
  });
}
