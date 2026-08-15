import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/s1_reading_card_style.dart';

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
    this.verticalMargin = 4,
    this.padding = const EdgeInsets.all(12),
    this.compactListFullBleed = false,
  });

  final Widget child;
  final double verticalMargin;
  final EdgeInsetsGeometry padding;
  final bool compactListFullBleed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: S1ReadingCardStyle.margin(
        context,
        enabled: compactListFullBleed,
        vertical: verticalMargin,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: S1SkeletonShapes.cardColor(scheme),
          borderRadius: S1ReadingCardStyle.inkBorderRadius(
            context,
            enabled: compactListFullBleed,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
