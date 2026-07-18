import 'package:flutter/material.dart';

/// 紧凑标签文字样式工具。
///
/// 为 [Chip] / [Badge] 等紧凑容器提供一致的 [labelSmall] 样式；
/// 使用平台默认行高，不做额外偏移补偿。
abstract final class CompactLabel {
  static const textHeightBehavior = TextHeightBehavior();

  static const visualNudge = Offset.zero;

  static TextStyle style(
    BuildContext context, {
    TextStyle? base,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return (base ?? Theme.of(context).textTheme.labelSmall)!.copyWith(
      color: color,
      fontWeight: fontWeight,
    );
  }

  static Widget text(
    String data, {
    required TextStyle style,
    Offset? nudge,
  }) {
    final child = Text(
      data,
      style: style,
      textHeightBehavior: textHeightBehavior,
    );
    final offset = nudge ?? visualNudge;
    if (offset == Offset.zero) return child;
    return Transform.translate(offset: offset, child: child);
  }
}
