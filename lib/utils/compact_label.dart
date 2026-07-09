import 'package:flutter/material.dart';

/// 紧凑标签文字修正工具。
///
/// Material [Chip] / [Badge] 配合 CJK 字体时，字形常在容器内视觉偏下；
/// 通过收紧行高、[TextHeightBehavior] 与微量上移补偿修正。
abstract final class CompactLabel {
  static const textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  /// CJK 在紧凑容器内的视觉上移补偿（约 0.5–1 逻辑像素）。
  static const visualNudge = Offset(0, -0.75);

  static TextStyle style(
    BuildContext context, {
    TextStyle? base,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return (base ?? Theme.of(context).textTheme.labelSmall)!.copyWith(
      height: 1.0,
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
