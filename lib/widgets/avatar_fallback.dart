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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _fallbackStyle(textTheme, radius);

    return CircleAvatar(
      radius: radius,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: EdgeInsets.all(radius * 0.18),
          child: Text(
            letter,
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// 按头像半径桥接 textTheme，大圆用更大字阶作 FittedBox 缩放基准。
  static TextStyle? _fallbackStyle(TextTheme textTheme, double radius) {
    if (radius >= 40) return textTheme.headlineLarge;
    if (radius >= 28) return textTheme.headlineMedium;
    if (radius >= 20) return textTheme.titleLarge;
    return textTheme.titleMedium;
  }
}
