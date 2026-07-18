import 'package:flutter/material.dart';

/// 头像加载失败时的首字母占位（字号随半径缩放，基于 textTheme）。
class AvatarFallbackLetter extends StatelessWidget {
  const AvatarFallbackLetter({
    super.key,
    required this.radius,
    required this.letter,
  });

  final double radius;
  final String letter;

  /// 收紧 ascent/descent 额外留白，避免排版盒高于墨水区。
  static const _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  /// 表意文字在 em 盒内视觉重心偏低，相对半径做光学上移。
  static const _ideographicNudgeFactor = 0.06;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _fallbackStyle(textTheme, radius);
    final nudgeY =
        _isIdeographic(letter) ? -radius * _ideographicNudgeFactor : 0.0;

    return CircleAvatar(
      radius: radius,
      child: Transform.translate(
        offset: Offset(0, nudgeY),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: EdgeInsets.all(radius * 0.18),
            child: Text(
              letter,
              textAlign: TextAlign.center,
              textHeightBehavior: _textHeightBehavior,
              style: style?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 中日韩表意/音节文字：字形铺满 em 盒，视觉重心常低于拉丁字母。
  @visibleForTesting
  static bool isIdeographic(String letter) => _isIdeographic(letter);

  static bool _isIdeographic(String letter) {
    if (letter.isEmpty) return false;
    final c = letter.runes.first;
    return (c >= 0x2E80 && c <= 0x9FFF) ||
        (c >= 0xAC00 && c <= 0xD7AF) ||
        (c >= 0xF900 && c <= 0xFAFF) ||
        (c >= 0xFF00 && c <= 0xFFEF) ||
        (c >= 0x20000 && c <= 0x2FA1F);
  }

  /// 按头像半径桥接 textTheme，大圆用更大字阶作 FittedBox 缩放基准。
  static TextStyle? _fallbackStyle(TextTheme textTheme, double radius) {
    if (radius >= 40) return textTheme.headlineLarge;
    if (radius >= 28) return textTheme.headlineMedium;
    if (radius >= 20) return textTheme.titleLarge;
    return textTheme.titleMedium;
  }
}
