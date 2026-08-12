import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'list_row_skeleton.dart';
import 'pm_bubble_skeleton.dart';
import 'post_item_skeleton.dart';
import 'thread_card_skeleton.dart';

/// 滑动翻页侧槽骨架样式（无真实数据，仅供横滑跟手预览）。
enum S1SwipeAdjacentSkeletonStyle {
  /// 通用列表行（私信、好友、通知等默认）。
  generic,

  /// 主题列表卡（版块、收藏、用户空间等）。
  threadCard,

  /// 帖子楼层（帖内回复）。
  postItem,

  /// 私信气泡（会话页）。
  pmBubble,
}

/// 三槽 [PageView] 邻页侧槽的满视口骨架列表。
class S1SwipeAdjacentSkeleton extends StatelessWidget {
  const S1SwipeAdjacentSkeleton({
    super.key,
    required this.style,
  });

  final S1SwipeAdjacentSkeletonStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: S1Surface.page(scheme),
      child: _buildSkeletonList(),
    );
  }

  Widget _buildSkeletonList() {
    switch (style) {
      case S1SwipeAdjacentSkeletonStyle.generic:
        return const ListRowSkeletonList();
      case S1SwipeAdjacentSkeletonStyle.threadCard:
        return const ThreadCardSkeletonList();
      case S1SwipeAdjacentSkeletonStyle.postItem:
        return const PostItemSkeletonList();
      case S1SwipeAdjacentSkeletonStyle.pmBubble:
        return const PmBubbleSkeletonList();
    }
  }
}
