import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../providers/api_service_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/thread_rate_logs_provider.dart';
import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import '../utils/post_image_index_counter.dart';
import 'bbcode_renderer.dart';
import 'post_action_menu.dart';
import 'rate_log_card.dart';
import 'user_profile_sheet.dart';
import 'web_avatar.dart';

class PostItem extends ConsumerStatefulWidget {
  const PostItem({
    super.key,
    required this.post,
    this.displayFloor,
    this.tid,
    this.onFilterByAuthor,
    this.onReply,
    this.onRate,
    this.isHighlighted = false,
    this.currentPage,
  });

  final Post post;
  final int? displayFloor;
  final String? tid;
  final VoidCallback? onFilterByAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onRate;
  final bool isHighlighted;
  final int? currentPage;

  @override
  ConsumerState<PostItem> createState() => _PostItemState();
}

class _PostItemState extends ConsumerState<PostItem> {
  bool _imagesExpanded = false;
  late PostImageIndexCounter _imageIndexCounter;

  @override
  void initState() {
    super.initState();
    _imageIndexCounter = PostImageIndexCounter();
  }

  @override
  void didUpdateWidget(PostItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.pid != widget.post.pid) {
      _imageIndexCounter = PostImageIndexCounter();
      _imagesExpanded = false;
    }
  }

  void _showUserInfo(BuildContext context, WidgetRef ref) {
    final currentUid = ref.read(authStateProvider).user?.uid;
    final future =
        ref.read(apiServiceProvider).getUserProfileByUid(widget.post.authorId);

    showUserProfileSheet(
      context,
      future: future,
      isSelf: currentUid != null && currentUid == widget.post.authorId,
      onFilterByAuthor: widget.onFilterByAuthor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStr = formatDateTime(widget.post.dateline);
    final floor = widget.displayFloor ?? widget.post.floor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: widget.isHighlighted
          ? scheme.primaryContainer.withValues(alpha: S1Alpha.half)
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
                    url: widget.post.avatar,
                    radius: 20,
                    fallbackLetter: widget.post.author.isNotEmpty
                        ? widget.post.author[0]
                        : '?',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.author,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                _FloorBadge(floor: floor),
                const SizedBox(width: 2),
                PostActionMenu(
                  onFilterByAuthor: widget.onFilterByAuthor,
                  onReply: widget.onReply,
                  onRate: widget.onRate,
                ),
              ],
            ),
            const Divider(height: 16),
            BbcodeRenderer(
              bbcode: widget.post.message,
              imageIndexCounter: _imageIndexCounter,
              currentTid: widget.tid,
              imagesExpanded: _imagesExpanded,
              onExpandImages: () => setState(() => _imagesExpanded = true),
            ),
            if (widget.tid != null)
              _PostRateLogSection(
                tid: widget.tid!,
                pid: widget.post.pid,
              ),
          ],
        ),
      ),
    );
  }
}

class _PostRateLogSection extends ConsumerWidget {
  const _PostRateLogSection({required this.tid, required this.pid});

  final String tid;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateLog = ref.watch(rateLogProvider((tid, pid)));
    if (rateLog == null || rateLog.isEmpty) {
      return const SizedBox.shrink();
    }
    return RateLogCard(tid: tid, pid: pid);
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

    return Badge(
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}
