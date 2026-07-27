import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 's1_skeleton_shapes.dart';
import 's1_viewport_skeleton_list.dart';

/// 头像 + 主/副标题行骨架（私信、好友、小黑屋、通知等）。
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});

  static const estimatedHeight = 88.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            S1SkeletonCircle(size: 44),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  S1SkeletonBar(width: 160),
                  SizedBox(height: 8),
                  S1SkeletonBar(),
                  SizedBox(height: 6),
                  S1SkeletonBar(widthFactor: 0.75, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 首屏满视口列表行骨架。
class ListRowSkeletonList extends StatelessWidget {
  const ListRowSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return S1ViewportSkeletonList(
      estimatedItemHeight: ListRowSkeleton.estimatedHeight,
      itemBuilder: (context, index) => const ListRowSkeleton(),
    );
  }
}
