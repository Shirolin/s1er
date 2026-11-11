import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/format_utils.dart';

void main() {
  group('formatFullCount', () {
    test('returns plain integer string without grouping', () {
      expect(formatFullCount(318), '318');
      expect(formatFullCount(1723), '1723');
      expect(formatFullCount(1234567), '1234567');
    });
  });

  group('formatLooseDateTime', () {
    test('pads quote header dates and keeps the year', () {
      expect(
        formatLooseDateTime('2026-11-7 16:44'),
        '2026-11-07 16:44',
      );
    });

    test('keeps older years', () {
      expect(
        formatLooseDateTime('2025-3-9 08:05'),
        '2025-03-09 08:05',
      );
    });

    test('returns unrecognized text unchanged', () {
      expect(formatLooseDateTime('某天某时'), '某天某时');
    });
  });

  group('formatRegDate', () {
    test('formats unix timestamp', () {
      // 2019-03-19 19:01:40 UTC+8 approx - use known timestamp
      const ts = 1552993300;
      final result = formatRegDate('$ts');
      expect(result, isNotEmpty);
      expect(result.contains('-'), isTrue);
    });

    test('truncates long date string to minute precision', () {
      expect(
        formatRegDate('2019-3-19 11:02:33'),
        '2019-3-19 11:02',
      );
    });

    test('returns empty for empty input', () {
      expect(formatRegDate(''), '');
    });
  });
}
