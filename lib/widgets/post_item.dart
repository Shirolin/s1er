import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../models/rate_log.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import 'bbcode_renderer.dart';
import 'post_action_menu.dart';
import 'rate_log_card.dart';
import 'user_profile_sheet.dart';
import 'web_avatar.dart';

class PostItem extends ConsumerWidget {
  const PostItem({
    super.key,
    required this.post,
    this.displayFloor,
    this.tid,
    this.onFilterByAuthor,
    this.onReply,
    this.rateLog,
    this.isHighlighted = false,
  });
  final Post post;
  final int? displayFloor;
  final String? tid;
  final VoidCallback? onFilterByAuthor;
  final VoidCallback? onReply;
  final PostRateLog? rateLog;
  final bool isHighlighted;

  void _showUserInfo(BuildContext context, WidgetRef ref) {
    final currentUid = ref.read(authStateProvider).user?.uid;
    final future = ref.read(apiServiceProvider).getUserProfileByUid(post.authorId);

    showUserProfileSheet(
      context,
      future: future,
      isSelf: currentUid != null && currentUid == post.authorId,
      onFilterByAuthor: onFilterByAuthor,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStr = formatDateTime(post.dateline);
    final floor = displayFloor ?? post.floor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isHighlighted
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerLow,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showUserInfo(context, ref),
                  child: WebAvatar(
                    url: post.avatar,
                    radius: 20,
                    fallbackLetter: post.author.isNotEmpty ? post.author[0] : '?',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),),
                      if (timeStr.isNotEmpty)
                        Text(timeStr,
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),),
                    ],
                  ),
                ),
                _FloorBadge(floor: floor),
                const SizedBox(width: 2),
                PostActionMenu(
                  onFilterByAuthor: onFilterByAuthor,
                  onReply: onReply,
                ),
              ],
            ),
            const Divider(height: 16),
            BbcodeRenderer(bbcode: post.message, currentTid: tid),
            if (rateLog != null && !rateLog!.isEmpty && tid != null)
              RateLogCard(rateLog: rateLog!, tid: tid!),
          ],
        ),
      ),
    );
  }
}

/// 楼层号展示徽章（只读，非交互）。
class _FloorBadge extends StatelessWidget {
  const _FloorBadge({required this.floor});

  final int floor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Chip(
      label: CompactLabel.text(
        '#$floor',
        style: CompactLabel.style(
          context,
          base: textTheme.labelSmall,
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: scheme.secondaryContainer,
      side: BorderSide.none,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
