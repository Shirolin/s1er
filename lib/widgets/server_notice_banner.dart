import 'package:flutter/material.dart';

/// 首页顶部的论坛官方公告条：只展示服务器原文，可关闭。
class ServerNoticeBanner extends StatelessWidget {
  const ServerNoticeBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  /// 服务器下发的公告原文。
  final String message;

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.campaign_outlined,
                size: 20,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '论坛公告',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: '关闭公告提示',
                icon: const Icon(Icons.close),
                color: scheme.onTertiaryContainer,
              ),
          ],
        ),
      ),
    );
  }
}
