import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/list_density.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_rate_logs_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/banned_post_detector.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/post_plain_text.dart';
import '../utils/quote_recovery_helper.dart';
import '../utils/s1_snack_bar.dart';
import 'bbcode_renderer.dart';
import 'post_action_menu.dart';
import 'rate_log_card.dart';
import 'user_profile_sheet.dart';
import 'web_avatar.dart';
import 's1_adaptive_sheet.dart';
import 's1_click_region.dart';

/// Spacing / layout tokens for [PostItem] chrome density (not body typography).
class PostItemDensityTokens {
  const PostItemDensityTokens({
    required this.cardMarginVertical,
    required this.cardPadding,
    required this.avatarRadius,
    required this.dividerHeight,
    required this.inlineAuthorMeta,
    required this.narrowColumnGap,
  });

  final double cardMarginVertical;
  final double cardPadding;
  final double avatarRadius;
  final double dividerHeight;
  final bool inlineAuthorMeta;
  final double narrowColumnGap;

  static const standard = PostItemDensityTokens(
    cardMarginVertical: 4,
    cardPadding: 12,
    avatarRadius: 20,
    dividerHeight: 16,
    inlineAuthorMeta: false,
    narrowColumnGap: 8,
  );

  static const compact = PostItemDensityTokens(
    cardMarginVertical: 2,
    cardPadding: 8,
    avatarRadius: 16,
    dividerHeight: 8,
    inlineAuthorMeta: true,
    narrowColumnGap: 4,
  );

  static PostItemDensityTokens forDensity(ListDensity density) {
    switch (density) {
      case ListDensity.compact:
        return compact;
      case ListDensity.standard:
        return standard;
    }
  }
}

class PostItem extends ConsumerStatefulWidget {
  const PostItem({
    super.key,
    required this.post,
    this.allPosts,
    this.onRequestSearchAllPages,
    this.displayFloor,
    this.tid,
    this.onFilterByAuthor,
    this.onReply,
    this.onEdit,
    this.onRate,
    this.onAddToBlacklist,
    this.onReport,
    this.onShare,
    this.onMultiShare,
    this.isHighlighted = false,
    this.isShareSelected = false,
    this.shareSelectMode = false,
    this.onShareSelectToggle,
    this.currentPage,
    this.highlightQuery,
  });

  final Post post;
  final List<Post>? allPosts;
  final Future<List<Post>> Function()? onRequestSearchAllPages;
  final int? displayFloor;
  final String? tid;
  final VoidCallback? onFilterByAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onRate;
  final VoidCallback? onAddToBlacklist;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onMultiShare;
  final bool isHighlighted;
  final bool isShareSelected;
  final bool shareSelectMode;
  final VoidCallback? onShareSelectToggle;
  final int? currentPage;

  /// 本页搜索关键词；非空时正文 `<mark>` 高亮。
  final String? highlightQuery;
  @override
  ConsumerState<PostItem> createState() => _PostItemState();
}

class _PostItemState extends ConsumerState<PostItem>
    with AutomaticKeepAliveClientMixin {
  bool _imagesExpanded = false;
  late PostImageIndexCounter _imageIndexCounter;

  /// 保留已构建楼层，避免滚出视口后销毁 Html（链接密集楼层重建可达秒级）。
  /// 内存换流畅：优先不卡顿，长帖内存略涨可接受。
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

  bool _recoveredQuoteExpanded = false;
  bool _isSearchingCrossPage = false;
  QuoteRecoveryResult? _crossPageResult;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final timeStr = formatDateTime(widget.post.dateline);
    final floor = widget.displayFloor ?? widget.post.floor;
    final isBanned = BannedPostDetector.isBanned(widget.post.message);
    final tokens = PostItemDensityTokens.forDensity(
      ref.watch(settingsProvider.select((s) => s.postListDensity)),
    );

    final selected = widget.shareSelectMode && widget.isShareSelected;
    final card = Card(
      margin: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: tokens.cardMarginVertical,
      ),
      elevation: 0,
      color: selected
          ? scheme.secondaryContainer.withValues(alpha: S1Alpha.half)
          : widget.isHighlighted
              ? scheme.primaryContainer.withValues(alpha: S1Alpha.half)
              : S1Surface.card(scheme),
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: S1Shape.medium,
              side: BorderSide(color: scheme.secondary, width: 1.5),
            )
          : S1Shape.cardShape,
      child: Padding(
        padding: EdgeInsets.all(tokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuthorHeader(context, timeStr, floor, tokens),
            Divider(
              height: tokens.dividerHeight,
              color: scheme.outlineVariant,
            ),
            if (isBanned)
              _buildBannedPostSection(context, scheme)
            else
              BbcodeRenderer(
                bbcode: widget.post.message,
                imageIndexCounter: _imageIndexCounter,
                currentTid: widget.tid,
                imagesExpanded: _imagesExpanded,
                onExpandImages: _expandImages,
                selectable: false,
                highlightQuery: widget.highlightQuery,
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

    if (!widget.shareSelectMode || widget.onShareSelectToggle == null) {
      return card;
    }

    return Semantics(
      selected: widget.isShareSelected,
      button: true,
      label: widget.isShareSelected ? '取消选中楼层' : '选中楼层',
      child: S1ClickRegion(
        onTap: widget.onShareSelectToggle,
        child: card,
      ),
    );
  }

  Future<void> _searchCrossPageQuotes() async {
    if (widget.onRequestSearchAllPages == null || _isSearchingCrossPage) return;
    setState(() => _isSearchingCrossPage = true);

    try {
      final allPosts = await widget.onRequestSearchAllPages!();
      final res = QuoteRecoveryHelper.findQuotesForPost(
        targetPost: widget.post,
        allPosts: allPosts,
      );
      if (!mounted) return;
      setState(() {
        _crossPageResult = res;
        if (res.hasQuotes) {
          _recoveredQuoteExpanded = true;
        } else {
          S1SnackBar.show(context, message: '全帖未搜索到其它用户的引用留痕');
        }
      });
    } catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '跨页搜索引用失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingCrossPage = false);
      }
    }
  }

  Widget _buildBannedPostSection(BuildContext context, ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;

    final localResult = QuoteRecoveryHelper.findQuotesForPost(
      targetPost: widget.post,
      allPosts: widget.allPosts ?? const [],
    );

    final effectiveResult = _crossPageResult ?? localResult;
    final hasQuote = effectiveResult.hasQuotes;
    final firstQuote = effectiveResult.firstQuote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: S1Alpha.half),
        borderRadius: S1Shape.medium,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasQuote ? Icons.history_edu_outlined : Icons.block_outlined,
                size: 20,
                color: scheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '作者已被论坛封禁或删除',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasQuote ? '（从回复中提取到历史发言引用）' : '（服务端已自动屏蔽原始正文）',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.outline,
            ),
          ),
          if (hasQuote && firstQuote != null) ...[
            const SizedBox(height: 10),
            if (!_recoveredQuoteExpanded)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _recoveredQuoteExpanded = true);
                },
                icon: const Icon(Icons.format_quote, size: 18),
                label: Text('查看从 #${firstQuote.sourceFloor} 楼提取的引用发言'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: S1Shape.small,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: S1Alpha.medium),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstQuote.recoveredText,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '提示：以上内容提取自 #${firstQuote.sourceFloor} 楼 @${firstQuote.sourceAuthor} 的引用',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              setState(() => _recoveredQuoteExpanded = false),
                          child: Text(
                            '收起',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (effectiveResult.totalCount > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '另有 ${effectiveResult.totalCount - 1} 条回复也引用了此发言',
                  style: textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ],
          ] else if (widget.onRequestSearchAllPages != null) ...[
            const SizedBox(height: 8),
            if (_isSearchingCrossPage)
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在跨页搜索全帖引用…',
                    style: textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: _searchCrossPageQuotes,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('跨页搜索全帖引用'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyPostText(BuildContext context) async {
    final plain = PostPlainText.fromMessage(widget.post.message);
    await Clipboard.setData(ClipboardData(text: plain));
    if (!context.mounted) return;
    S1Haptics.light();
    S1SnackBar.show(context, message: '已复制');
  }

  void _showSelectTextSheet(BuildContext context) {
    showS1AdaptiveSheet(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择文字',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: BbcodeRenderer(
                    bbcode: widget.post.message,
                    imageIndexCounter: PostImageIndexCounter(),
                    currentTid: widget.tid,
                    imagesExpanded: true,
                    selectable: true,
                    highlightQuery: widget.highlightQuery,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthorHeader(
    BuildContext context,
    String timeStr,
    int floor,
    PostItemDensityTokens tokens,
  ) {
    final canCopy = widget.post.message.trim().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    if (widget.shareSelectMode) {
      return Row(
        children: [
          Icon(
            widget.isShareSelected
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            color: widget.isShareSelected
                ? scheme.secondary
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _authorDetails(
              context,
              timeStr,
              inline: tokens.inlineAuthorMeta,
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            label: Text(
              '#$floor',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            backgroundColor: scheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
        ],
      );
    }

    final menu = PostActionMenu(
      onFilterByAuthor: widget.onFilterByAuthor,
      onReply: widget.onReply,
      onShare: widget.onShare,
      onMultiShare: widget.onMultiShare,
      onSelectText: canCopy ? () => _showSelectTextSheet(context) : null,
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
          radius: tokens.avatarRadius,
          fallbackLetter:
              widget.post.author.isNotEmpty ? widget.post.author[0] : '?',
        ),
      ),
    );
    final authorDetails = _authorDetails(
      context,
      timeStr,
      inline: tokens.inlineAuthorMeta,
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
              SizedBox(height: tokens.narrowColumnGap),
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

  Widget _authorDetails(
    BuildContext context,
    String timeStr, {
    required bool inline,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final nameStyle =
        textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final timeStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    if (inline) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: widget.post.author, style: nameStyle),
            if (timeStr.isNotEmpty) ...[
              TextSpan(text: ' · ', style: timeStyle),
              TextSpan(text: timeStr, style: timeStyle),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        if (timeStr.isNotEmpty)
          Text(
            timeStr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: timeStyle,
          ),
      ],
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
    return RateLogCard(tid: tid, pid: pid, rateLog: rateLog);
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
