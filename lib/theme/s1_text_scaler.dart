import 'package:flutter/painting.dart';

/// 把应用内字号档位叠在系统文字缩放**之上**（而非替换）。
///
/// 原实现 `copyWith(textScaler: TextScaler.linear(factor))` 会丢弃平台的无障碍
/// 字号：系统 150% 的用户在应用内仍按 100% 渲染。这里先应用应用内比例，再走平台
/// 曲线，因此 Android 14+ 的非线性字体缩放也能正确处理。
///
/// 只覆写 [scale]：平台侧的非线性映射由 [platform] 自己决定，不做线性近似。
final class S1ComposedTextScaler extends TextScaler {
  const S1ComposedTextScaler(this.platform, this.factor);

  /// 总比例下限：档位最小档 12/14 ≈ 0.857，再低会小到不可读。
  static const double minTotalScale = 0.85;

  /// 总比例上限：最大档 1.43 × 系统 1.4 已接近 2.0，再大会撑破布局。
  static const double maxTotalScale = 2.0;

  /// 平台 / 引擎下发的原始缩放。
  final TextScaler platform;

  /// 应用内档位比例（`fontSize / defaultBodySize`）。
  final double factor;

  /// 复合平台缩放与档位，并把总比例夹在可布局范围内。
  static TextScaler compose(TextScaler platform, double factor) =>
      S1ComposedTextScaler(platform, factor).clamp(
        minScaleFactor: minTotalScale,
        maxScaleFactor: maxTotalScale,
      );

  @override
  double scale(double fontSize) => platform.scale(fontSize * factor);

  /// 仅向后兼容用的估计值；避免调用已废弃的 `platform.textScaleFactor`。
  @override
  double get textScaleFactor => scale(100) / 100;

  @override
  bool operator ==(Object other) =>
      other is S1ComposedTextScaler &&
      other.platform == platform &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(platform, factor);
}
