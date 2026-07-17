import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/thread_rate_logs_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/post_plain_text.dart';
import '../utils/s1_snack_bar.dart';
import 'bbcode_renderer.dart';
import 'post_action_menu.dart';
import 'rate_log_card.dart';
import 'user_profile_sheet.dart';
import 'web_avatar.dart';
import 's1_click_region.dart';

class PostItem extends ConsumerStatefulWidget {
  const PostItem({
    super.key,
    required this.post,
    this.displayFloor,
    this.tid,
    this.onFilterByAuthor,
    this.onReply,
    this.onEdit,
    this.onRate,
    this.onAddToBlacklist,
    this.onReport,
    this.onShare,
    this.isHighlighted = false,
    this.currentPage,
  });

  final Post post;
  final int? displayFloor;
  final String? tid;
  final VoidCallback? onFilterByAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onRate;
  final VoidCallback? onAddToBlacklist;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final bool isHighlighted;
  final int? currentPage;

  @override
  ConsumerState<PostItem> createState() => _PostItemState();
}

class _PostItemState extends ConsumerState<PostItem>
    with AutomaticKeepAliveClientMixin {
  bool _imagesExpanded = false;
  late PostImageIndexCounter _imageIndexCounter;

  /// 保留已构建楼层，避免滚出视口后销毁 Html（链接密集楼层重建可达秒级）。
  @override
  bool get wantKeepAlive => true;

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
    final future = ref.read(userProfileProvider(widget.post.authorId).future);

    showUserProfileSheet(
      context,
      future: future,
      isSelf: currentUid != null && currentUid == widget.post.authorId,
      onFilterByAuthor: widget.onFilterByAuthor,
    );
  }

  /// 展开折叠图片：锁住当前滚动偏移，避免焦点迁移 / 高度突变把视口甩走。
  void _expandImages() {
    FocusManager.instance.primaryFocus?.unfocus();
    final position = Scrollable.maybeOf(context)?.position;
    final lockedPixels = position?.pixels;

    setState(() => _imagesExpanded = true);

    void restoreScroll() {
      if (!mounted || position == null || lockedPixels == null) return;
      if (!position.hasPixels || !position.hasContentDimensions) return;
      final target = lockedPixels.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 1) {
        position.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreScroll();
      // 焦点转移可能发生在首帧之后。
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreScroll());
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
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
            _buildAuthorHeader(context, timeStr, floor),
            Divider(height: 16, color: scheme.outlineVariant),
            BbcodeRenderer(
              bbcode: widget.post.message,
              imageIndexCounter: _imageIndexCounter,
              currentTid: widget.tid,
              imagesExpanded: _imagesExpanded,
              onExpandImages: _expandImages,
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

  Future<void> _copyPostText(BuildContext context) async {
    final plain = PostPlainText.fromMessage(widget.post.message);
    await Clipboard.setData(ClipboardData(text: plain));
    if (!context.mounted) return;
    S1SnackBar.show(context, message: '已复制');
  }

  Widget _buildAuthorHeader(BuildContext context, String timeStr, int floor) {
    final canCopy = widget.post.message.trim().isNotEmpty;
    final menu = PostActionMenu(
      onFilterByAuthor: widget.onFilterByAuthor,
      onReply: widget.onReply,
      onShare: widget.onShare,
      onCopyText: canCopy ? () => _copyPostText(context) : null,
      onEdit: widget.onEdit,
      onRate: widget.onRate,
      onAddToBlacklist: widget.onAddToBlacklist,
      onReport: widget.onReport,
    );

    final avatar = Semantics(
      button: true,
      label: '查看 ${widget.post.author} 的资料',
      child: S1ClickRegion(
        onTap: () => _showUserInfo(context, ref),
        child: WebAvatar(
          url: widget.post.avatar,
          radius: 20,
          fallbackLetter:
              widget.post.author.isNotEmpty ? widget.post.author[0] : '?',
        ),
      ),
    );
    final authorDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (timeStr.isNotEmpty)
          Text(
            timeStr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
    final actions = Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        _FloorBadge(floor: floor),
        menu,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(height: 8),
              authorDetails,
              if (constraints.maxWidth >= 80) actions,
            ],
          );
        }

        return Row(
          children: [
            avatar,
            const SizedBox(width: 8),
            Expanded(child: authorDetails),
            _FloorBadge(floor: floor),
            const SizedBox(width: 2),
            menu,
          ],
        );
      },
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
