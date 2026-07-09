import 'package:flutter/material.dart';

import 's1_popup_menu.dart';

enum _PostAction { filterAuthor, reply, rate, report }

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
    return PopupMenuButton<_PostAction>(
      tooltip: '更多操作',
      icon: const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onSelected: (action) {
        switch (action) {
          case _PostAction.filterAuthor:
            onFilterByAuthor?.call();
          case _PostAction.reply:
            onReply?.call();
          case _PostAction.rate:
            onRate?.call();
          case _PostAction.report:
            onReport?.call();
        }
      },
      itemBuilder: (context) => [
        s1PopupMenuItem(
          value: _PostAction.filterAuthor,
          icon: Icons.person_search_outlined,
          label: '只看该作者',
          enabled: onFilterByAuthor != null,
        ),
        s1PopupMenuItem(
          value: _PostAction.reply,
          icon: Icons.reply_outlined,
          label: '回复',
          enabled: onReply != null,
        ),
        s1PopupMenuItem(
          value: _PostAction.rate,
          icon: Icons.favorite_outline,
          label: '评分',
          enabled: onRate != null,
        ),
        const PopupMenuDivider(),
        s1PopupMenuItem(
          value: _PostAction.report,
          icon: Icons.flag_outlined,
          label: '举报',
          enabled: onReport != null,
          destructive: true,
        ),
      ],
    );
  }
}
