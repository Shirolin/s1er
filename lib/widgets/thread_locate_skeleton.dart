import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'skeleton/post_item_skeleton.dart';

/// 帖子详情楼层定位期间的占位骨架（遮在真列表之上，定位完成后移除）。
class ThreadLocateSkeleton extends StatelessWidget {
  const ThreadLocateSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: S1Surface.page(scheme),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          PostItemSkeleton(),
          PostItemSkeleton(),
          PostItemSkeleton(),
        ],
      ),
    );
  }
}
