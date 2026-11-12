import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/s1_text_scaler.dart';

void main() {
  group('S1ComposedTextScaler', () {
    test('multiplies the platform scale instead of replacing it', () {
      final scaler =
          S1ComposedTextScaler.compose(const TextScaler.linear(1.2), 20 / 14);

      // 1.2 × 1.4286 ≈ 1.714
      expect(scaler.scale(14), closeTo(24, 0.001));
      expect(scaler.scale(100), closeTo(171.43, 0.01));
    });

    test('keeps the chosen step when the platform does not scale', () {
      final scaler =
          S1ComposedTextScaler.compose(TextScaler.noScaling, 16 / 14);

      expect(scaler.scale(14), closeTo(16, 0.001));
    });

    test('clamps the total ratio into a layout-safe range', () {
      // 系统 2.0 × 档位 1.43 = 2.86 → 夹到 2.0
      final huge =
          S1ComposedTextScaler.compose(const TextScaler.linear(2.0), 20 / 14);
      expect(huge.scale(14), closeTo(28, 0.001));

      // 系统 0.5 × 档位 0.857 = 0.43 → 抬到 0.85
      final tiny =
          S1ComposedTextScaler.compose(const TextScaler.linear(0.5), 12 / 14);
      expect(tiny.scale(14), closeTo(11.9, 0.001));
    });

    test('composes in step-then-curve order on non-linear platforms', () {
      // 平台曲线在大字号处递减：20px 只放大到 18px。
      const nonLinear = _CompressingScaler();
      final scaler = S1ComposedTextScaler.compose(nonLinear, 20 / 14);

      // 先把档位乘上去（14 → 20），再走平台曲线（20 → 18），
      // 即不是可交换的“档位 × 平台”，大档位会被曲线压低。
      expect(scaler.scale(14), closeTo(18, 0.001));
      // 若按乘法可交换理解（先曲线再档位）会得到 14 × 1.43 ≈ 20。
      expect(scaler.scale(14), lessThan(20));
    });

    test('equality and hashCode follow platform + factor', () {
      const a = S1ComposedTextScaler(TextScaler.linear(1.3), 1.2);
      const b = S1ComposedTextScaler(TextScaler.linear(1.3), 1.2);
      const c = S1ComposedTextScaler(TextScaler.linear(1.3), 1.4);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}

/// 模拟 Android 14+ 的非线性字体缩放：16px 以上增长减速。
class _CompressingScaler extends TextScaler {
  const _CompressingScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize : 16 + (fontSize - 16) * 0.5;

  @override
  double get textScaleFactor => 1.0;
}
