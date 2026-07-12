import 'package:flutter/material.dart';

import 's1_menu.dart';

/// 帖子上下文操作菜单（⋮ 触发，向下弹出）。
class PostActionMenu extends StatelessWidget {
  const PostActionMenu({
    super.key,
    this.onFilterByAuthor,
    this.onReply,
    this.onRate,
    this.onReport,
  });

  final VoidCallback? onFilterByAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onRate;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return S1IconMenuAnchor(
      menuChildren: [
        s1MenuItem(
          onPressed: onFilterByAuthor,
          icon: Icons.person_search_outlined,
          label: '只看该作者',
        ),
        s1MenuItem(
          onPressed: onReply,
          icon: Icons.reply_outlined,
          label: '回复',
        ),
        s1MenuItem(
          onPressed: onRate,
          icon: Icons.favorite_outline,
          label: '评分',
        ),
        const S1MenuDivider(),
        s1MenuItem(
          onPressed: onReport,
          icon: Icons.flag_outlined,
          label: '举报',
          destructive: true,
        ),
      ],
    );
  }
}
