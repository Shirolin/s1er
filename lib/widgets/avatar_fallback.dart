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

    return CircleAvatar(
      radius: radius,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(radius * 0.2),
          child: Text(
            letter,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
