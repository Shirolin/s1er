import 'package:flutter/material.dart';

import '../models/private_message.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class PmMessageBubble extends StatelessWidget {
  const PmMessageBubble({super.key, required this.message});

  final PrivateMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final alignment =
        message.isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isOutgoing
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final foreground =
        message.isOutgoing ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: alignment,
      child: Card(
        elevation: 0,
        color: color,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: S1Shape.cardShape,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message.isEmpty ? '（空消息）' : message.message,
                  style: textTheme.bodyMedium?.copyWith(color: foreground),
                ),
                const SizedBox(height: 6),
                Text(
                  formatTimeAgo(message.dateline),
                  style: textTheme.labelSmall?.copyWith(
                    color: message.isOutgoing
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
