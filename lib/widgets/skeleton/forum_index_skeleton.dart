import 'package:flutter/material.dart';

import 's1_skeleton_shapes.dart';

/// 版块首页分类卡骨架（2 组分类 + 子版块行）。
class ForumIndexSkeleton extends StatelessWidget {
  const ForumIndexSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [
        _ForumCategorySkeletonCard(),
        _ForumCategorySkeletonCard(),
      ],
    );
  }
}

class _ForumCategorySkeletonCard extends StatelessWidget {
  const _ForumCategorySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                S1SkeletonCircle(size: 18),
                SizedBox(width: 8),
                S1SkeletonBar(width: 120, height: 16),
              ],
            ),
          ),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  S1SkeletonBar(width: 180, height: 14),
                  Spacer(),
                  S1SkeletonBar(width: 36, height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
