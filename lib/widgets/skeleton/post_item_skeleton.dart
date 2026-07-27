import 'package:flutter/material.dart';

import 's1_skeleton_shapes.dart';
import 's1_viewport_skeleton_list.dart';

/// 对齐 [PostItem] 的帖子楼层骨架。
class PostItemSkeleton extends StatelessWidget {
  const PostItemSkeleton({super.key});

  static const estimatedHeight = 168.0;

  @override
  Widget build(BuildContext context) {
    return const S1SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              S1SkeletonCircle(size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    S1SkeletonBar(width: 96),
                    SizedBox(height: 8),
                    S1SkeletonBar(width: 64, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          S1SkeletonBar(),
          SizedBox(height: 8),
          S1SkeletonBar(),
          SizedBox(height: 8),
          S1SkeletonBar(widthFactor: 0.72),
        ],
      ),
    );
  }
}

/// 首屏满视口帖子骨架列表。
class PostItemSkeletonList extends StatelessWidget {
  const PostItemSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return S1ViewportSkeletonList(
      estimatedItemHeight: PostItemSkeleton.estimatedHeight,
      itemBuilder: (context, index) => const PostItemSkeleton(),
    );
  }
}
