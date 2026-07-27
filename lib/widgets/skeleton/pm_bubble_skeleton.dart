import 'package:flutter/material.dart';

import 's1_skeleton_shapes.dart';
import 's1_viewport_skeleton_list.dart';

class PmBubbleSkeleton extends StatelessWidget {
  const PmBubbleSkeleton({
    super.key,
    required this.alignEnd,
  });

  final bool alignEnd;

  static const estimatedHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: S1SkeletonShapes.barColor(scheme),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(alignEnd ? 16 : 4),
          bottomRight: Radius.circular(alignEnd ? 4 : 16),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            S1SkeletonBar(widthFactor: 0.9, height: 12),
            SizedBox(height: 6),
            S1SkeletonBar(widthFactor: 0.55, height: 12),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: bubble,
          ),
        ],
      ),
    );
  }
}

/// 首屏满视口私信气泡骨架（左右交替）。
class PmBubbleSkeletonList extends StatelessWidget {
  const PmBubbleSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return S1ViewportSkeletonList(
      estimatedItemHeight: PmBubbleSkeleton.estimatedHeight,
      itemBuilder: (context, index) => PmBubbleSkeleton(alignEnd: index.isOdd),
    );
  }
}
