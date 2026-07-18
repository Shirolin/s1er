import 'package:flutter/material.dart';
import '../models/private_message_item.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'web_avatar.dart';

class PmListTile extends StatelessWidget {
  const PmListTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final PrivateMessageItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final letter =
        item.partnerName.isNotEmpty ? item.partnerName.characters.first : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: ListTile(
        onTap: onTap,
        shape: S1Shape.cardShape,
        leading: WebAvatar(
          url: item.avatarUrl,
          radius: 22,
          fallbackLetter: letter,
        ),
        title: Text(
          item.isOutgoing
              ? '我对 ${item.partnerName} 说'
              : '${item.partnerName} 对我说',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall,
        ),
        subtitle: Text(
          item.preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: Text(
          formatTimeAgo(item.dateline),
          style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
