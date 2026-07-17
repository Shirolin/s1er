import 'package:flutter/material.dart';

/// WCAG 2.1 对比度计算（用于 UI 组件色与正文作者色校验）。
abstract final class ColorContrast {
  /// 两色之间的对比度比值（≥ 1.0）。
  static double ratio(Color foreground, Color background) {
    final l1 = foreground.computeLuminance();
    final l2 = background.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 非文本 UI 组件最低对比度（WCAG 1.4.11，3:1）。
  static bool meetsNonTextContrast(Color foreground, Color background) {
    return ratio(foreground, background) >= 3.0;
  }

  /// 正文文本最低对比度（WCAG 1.4.3 AA，4.5:1）。
  static bool meetsTextContrast(Color foreground, Color background) {
    return ratio(foreground, background) >= 4.5;
  }
}
