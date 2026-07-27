import 'package:flutter/material.dart';

import 's1_skeleton_shapes.dart';
import 's1_viewport_skeleton_list.dart';

/// 对齐 [ThreadCard] 的主题列表项骨架。
class ThreadCardSkeleton extends StatelessWidget {
  const ThreadCardSkeleton({super.key});

  static const estimatedHeight = 108.0;

  @override
  Widget build(BuildContext context) {
    return const S1SkeletonCard(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          S1SkeletonBar(),
          SizedBox(height: 6),
          S1SkeletonBar(widthFactor: 0.82),
          SizedBox(height: 10),
          S1SkeletonBar(width: 220, height: 12),
          SizedBox(height: 10),
          S1SkeletonBar(height: 4),
        ],
      ),
    );
  }
}

/// 首屏满视口主题卡骨架列表。
class ThreadCardSkeletonList extends StatelessWidget {
  const ThreadCardSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return S1ViewportSkeletonList(
      estimatedItemHeight: ThreadCardSkeleton.estimatedHeight,
      itemBuilder: (context, index) => const ThreadCardSkeleton(),
    );
  }
}
