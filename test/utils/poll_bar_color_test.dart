import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/color_contrast.dart';
import 'package:s1er/utils/poll_bar_color.dart';

void main() {
  group('ColorContrast', () {
    test('black on white has high contrast', () {
      expect(
        ColorContrast.ratio(Colors.black, Colors.white),
        greaterThan(10),
      );
    });

    test('similar colors fail non-text contrast', () {
      const a = Color(0xFFE0E0E0);
      const b = Color(0xFFE8E8E8);
      expect(ColorContrast.meetsNonTextContrast(a, b), isFalse);
    });

    test('black on white meets text contrast', () {
      expect(
        ColorContrast.meetsTextContrast(Colors.black, Colors.white),
        isTrue,
      );
    });

    test('light gray on white fails text contrast', () {
      expect(
        ColorContrast.meetsTextContrast(
          const Color(0xFFCCCCCC),
          Colors.white,
        ),
        isFalse,
      );
    });
  });

  group('pollBarColor', () {
    test('uses API color when contrast is sufficient', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.purple);
      final color = pollBarColor('1B5E20', scheme);
      expect(color, const Color(0xFF1B5E20));
    });

    test('falls back to primary when contrast is insufficient', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.purple);
      // Near-white bar on surfaceContainerHighest track
      final color = pollBarColor('F5F5F5', scheme);
      expect(color, scheme.primary);
    });

    test('falls back to primary for invalid hex', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.purple);
      expect(pollBarColor('ZZZZZZ', scheme), scheme.primary);
      expect(pollBarColor('', scheme), scheme.primary);
    });
  });
}
