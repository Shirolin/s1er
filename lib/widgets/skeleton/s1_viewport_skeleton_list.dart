import 'package:flutter/material.dart';

/// 按视口高度估算条数，填满首屏骨架列表（[minCount]–[maxCount]）。
class S1ViewportSkeletonList extends StatelessWidget {
  const S1ViewportSkeletonList({
    super.key,
    required this.estimatedItemHeight,
    required this.itemBuilder,
    this.minCount = 3,
    this.maxCount = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final double estimatedItemHeight;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int minCount;
  final int maxCount;
  final EdgeInsets padding;
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        var count = minCount;
        if (maxHeight.isFinite && estimatedItemHeight > 0) {
          count = (maxHeight / estimatedItemHeight).ceil();
        }
        count = count.clamp(minCount, maxCount);
        return ListView.builder(
          physics: physics,
          padding: padding,
          itemCount: count,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
