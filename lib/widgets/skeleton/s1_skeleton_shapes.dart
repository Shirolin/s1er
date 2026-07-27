import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// M3 骨架基础形状（色取自 [ColorScheme] / [TextTheme]）。
abstract class S1SkeletonShapes {
  static double barHeight(TextTheme textTheme) =>
      textTheme.bodyMedium?.fontSize ?? 14;

  static Color barColor(ColorScheme scheme) => scheme.surfaceContainerHighest;

  static Color cardColor(ColorScheme scheme) => scheme.surfaceContainerLow;
}

class S1SkeletonBar extends StatelessWidget {
  const S1SkeletonBar({
    super.key,
    this.width,
    this.height,
    this.widthFactor,
  });

  final double? width;
  final double? height;
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bar = Container(
      height: height ?? S1SkeletonShapes.barHeight(textTheme),
      width: width,
      decoration: BoxDecoration(
        color: S1SkeletonShapes.barColor(scheme),
        borderRadius: S1Shape.extraSmall,
      ),
    );
    if (widthFactor != null) {
      return FractionallySizedBox(widthFactor: widthFactor, child: bar);
    }
    return bar;
  }
}

class S1SkeletonCircle extends StatelessWidget {
  const S1SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: S1SkeletonShapes.barColor(scheme),
        shape: BoxShape.circle,
      ),
    );
  }
}

class S1SkeletonCard extends StatelessWidget {
  const S1SkeletonCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: S1SkeletonShapes.cardColor(scheme),
          borderRadius: S1Shape.medium,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
