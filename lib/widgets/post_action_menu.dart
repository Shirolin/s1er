import 'package:flutter/material.dart';

import 's1_menu.dart';

/// 帖子上下文操作菜单（⋮ 触发，向下弹出）。
class PostActionMenu extends StatelessWidget {
  const PostActionMenu({
    super.key,
    this.onFilterByAuthor,
    this.onReply,
    this.onEdit,
    this.onRate,
    this.onAddToBlacklist,
    this.onReport,
    this.onShare,
    this.onMultiShare,
    this.onCopyText,
    this.onSelectText,
  });

  final VoidCallback? onFilterByAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onRate;
  final VoidCallback? onAddToBlacklist;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onMultiShare;
  final VoidCallback? onCopyText;
  final VoidCallback? onSelectText;

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
          onPressed: onShare,
          icon: Icons.share_outlined,
          label: '分享',
        ),
        s1MenuItem(
          onPressed: onMultiShare,
          icon: Icons.library_add_check_outlined,
          label: '多选分享',
        ),
        s1MenuItem(
          onPressed: onSelectText,
          icon: Icons.text_format_outlined,
          label: '选择文字',
        ),
        s1MenuItem(
          onPressed: onCopyText,
          icon: Icons.copy_outlined,
          label: '复制全文',
        ),
        s1MenuItem(
          onPressed: onEdit,
          icon: Icons.edit_outlined,
          label: '编辑',
        ),
        s1MenuItem(
          onPressed: onRate,
          icon: Icons.favorite_outline,
          label: '评分',
        ),
        s1MenuItem(
          onPressed: onAddToBlacklist,
          icon: Icons.block_outlined,
          label: '加入黑名单',
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
