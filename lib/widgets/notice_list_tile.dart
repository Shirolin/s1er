import 'package:flutter/material.dart';
import '../models/notice_item.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
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

  /// 提醒正文以作者名开头（`作者 回复了您的帖子 …`），而标题行已显示作者名。
  /// 重复一遍只会挤掉正文，读屏也会连读两次。
  static String summaryWithoutAuthor(String summary, String authorName) {
    final text = summary.trimLeft();
    if (authorName.isEmpty || !text.startsWith(authorName)) return summary;
    final rest =
        text.substring(authorName.length).replaceFirst(RegExp(r'^\s*'), '');
    return rest.isEmpty ? summary : rest;
  }

  /// 摘要末尾的「查看」是提醒里的链接文字，整行已可点击，留着只是噪声。
  static String displaySummary(String summary, String authorName) {
    final text = summaryWithoutAuthor(summary, authorName)
        .replaceFirst(RegExp(r'\s*查看\s*$'), '')
        .trimRight();
    return text.isEmpty ? summary : text;
  }

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
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: ListTile(
        onTap: item.canNavigate ? S1Haptics.wrapTap(onTap) : null,
        shape: S1Shape.cardShape,
        leading: ExcludeSemantics(
          // 头像首字母只是占位，混进合并后的按钮文本会成为噪声。
          child: WebAvatar(
            url: item.avatarUrl,
            radius: 22,
            fallbackLetter: letter,
          ),
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
          displaySummary(item.summary, item.authorName),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
