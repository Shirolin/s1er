import 'package:flutter/material.dart';

/// 紧凑标签文字样式工具。
///
/// 为 [Chip] / [Badge] 等紧凑容器提供一致的 [labelSmall] 样式。
/// 收紧 ascent/descent 额外留白；表意文字再做轻微光学上移（与头像 fallback 同因）。
abstract final class CompactLabel {
  /// 不把行高加到首行 ascent / 末行 descent，避免字盒高于墨水区。
  static const textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  /// 显式传入 [text] 的 `nudge` 时的基准；默认无额外全局偏移。
  static const visualNudge = Offset.zero;

  /// 表意文字相对字号的光学上移（与头像首字母占位同系数）。
  static const ideographicNudgeFactor = 0.06;

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
    final offset = nudge ?? _autoNudge(data, style);
    if (offset == Offset.zero) return child;
    return Transform.translate(offset: offset, child: child);
  }

  /// 含中日韩表意/音节文字时，字形铺满 em 盒，视觉重心常低于拉丁字母。
  static bool containsIdeographic(String data) {
    for (final c in data.runes) {
      if ((c >= 0x2E80 && c <= 0x9FFF) ||
          (c >= 0xAC00 && c <= 0xD7AF) ||
          (c >= 0xF900 && c <= 0xFAFF) ||
          (c >= 0xFF00 && c <= 0xFFEF) ||
          (c >= 0x20000 && c <= 0x2FA1F)) {
        return true;
      }
    }
    return false;
  }

  static Offset _autoNudge(String data, TextStyle style) {
    if (!containsIdeographic(data)) return visualNudge;
    final size = style.fontSize ?? 11;
    return Offset(0, -size * ideographicNudgeFactor);
  }
}
