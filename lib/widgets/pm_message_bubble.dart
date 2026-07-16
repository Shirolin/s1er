import 'package:flutter/material.dart';

import '../models/private_message.dart';
import '../models/private_message_item.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'web_avatar.dart';

class PmMessageBubble extends StatelessWidget {
  const PmMessageBubble({
    super.key,
    required this.message,
    this.compact = false,
  });

  final PrivateMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = message.isOutgoing
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final foreground =
        message.isOutgoing ? scheme.onPrimaryContainer : scheme.onSurface;
    final fallbackName = message.isOutgoing ? '我' : '对方';
    final displayName = message.authorName.trim().isEmpty
        ? fallbackName
        : message.authorName.trim();
    final avatarUrl = PrivateMessageItem.avatarUrlForUid(message.authorId);
    final formattedTime = formatDateTime(message.dateline);
    final messageTime = formattedTime.isEmpty ? '时间未知' : formattedTime;

    final bubble = Card(
      elevation: 0,
      color: color,
      margin: EdgeInsets.zero,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message.isEmpty ? '（空消息）' : message.message,
              style: textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );

    final messageColumn = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: message.isOutgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$displayName  ·  $messageTime',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            bubble,
          ],
        ),
      ),
    );

    final avatar = WebAvatar(
      url: avatarUrl,
      radius: compact ? 16 : 18,
      fallbackLetter: displayName.characters.first,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 5 : 6,
      ),
      child: Row(
        mainAxisAlignment: message.isOutgoing
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.isOutgoing
            ? [messageColumn, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), messageColumn],
      ),
    );
  }
}
