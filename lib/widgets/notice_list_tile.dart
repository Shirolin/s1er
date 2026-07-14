import 'package:flutter/material.dart';
import '../models/notice_item.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'web_avatar.dart';

class NoticeListTile extends StatelessWidget {
  const NoticeListTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final NoticeItem item;
  final VoidCallback onTap;

  IconData _iconForType() {
    switch (item.type) {
      case NoticeType.reply:
        return Icons.reply;
      case NoticeType.rate:
        return Icons.star_outline;
      case NoticeType.other:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final letter =
        item.authorName.isNotEmpty ? item.authorName.characters.first : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: S1Shape.cardShape,
      child: ListTile(
        onTap: item.canNavigate ? onTap : null,
        shape: S1Shape.cardShape,
        leading: WebAvatar(
          url: item.avatarUrl,
          radius: 22,
          fallbackLetter: letter,
        ),
        title: Row(
          children: [
            Icon(
              _iconForType(),
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
            ),
            Text(
              formatTimeAgo(item.dateline),
              style: textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        subtitle: Text(
          item.summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
