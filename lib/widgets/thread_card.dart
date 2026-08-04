import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/constants.dart';
import '../models/list_density.dart';
import '../models/thread.dart';
import '../providers/reading_history_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../models/thread_destination.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import '../utils/thread_navigation.dart';
import 'page_picker_sheet.dart';

typedef ThreadOpenCallback = void Function(
  ThreadDestination destination, {
  int? resumePageHint,
});

/// `null` 表示取消筛选。
typedef ThreadTypeFilterCallback = void Function(String? typeId);

/// Spacing / layout tokens for [ThreadCard] density modes.
class ThreadCardDensityTokens {
  const ThreadCardDensityTokens({
    required this.cardMarginVertical,
    required this.cardPaddingVertical,
    required this.titleMetaGap,
    required this.titleMaxLines,
    required this.titleHeight,
    required this.progressTop,
    required this.inlineTag,
    required this.tagMaxChars,
    required this.showProgressBar,
    required this.showPageChip,
    required this.categoryChipVisualDensity,
    required this.categoryChipLabelPadding,
    required this.categoryFilterBarPadding,
  });

  final double cardMarginVertical;
  final double cardPaddingVertical;
  final double titleMetaGap;
  final int titleMaxLines;
  final double titleHeight;
  final double progressTop;
  final bool inlineTag;

  /// Max category tag characters when [inlineTag]; null = no truncation.
  final int? tagMaxChars;

  /// Standard density: 2px reading progress bar under meta row.
  final bool showProgressBar;

  /// Meta-row page picker chip (compact hides to save horizontal space).
  final bool showPageChip;

  final VisualDensity categoryChipVisualDensity;
  final EdgeInsetsGeometry categoryChipLabelPadding;
  final EdgeInsets categoryFilterBarPadding;

  static const standard = ThreadCardDensityTokens(
    cardMarginVertical: 5,
    cardPaddingVertical: 10,
    titleMetaGap: 11,
    titleMaxLines: 2,
    titleHeight: 1.4,
    progressTop: 6,
    inlineTag: true,
    tagMaxChars: null,
    showProgressBar: true,
    showPageChip: true,
    categoryChipVisualDensity: VisualDensity(horizontal: -1, vertical: -2),
    categoryChipLabelPadding: EdgeInsets.symmetric(horizontal: 5),
    categoryFilterBarPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  );

  static const _compactCategoryChipVisualDensity =
      VisualDensity(horizontal: -2, vertical: -4);

  static const compact = ThreadCardDensityTokens(
    cardMarginVertical: 2,
    cardPaddingVertical: 5,
    titleMetaGap: 4,
    titleMaxLines: 1,
    titleHeight: 1.3,
    progressTop: 4,
    inlineTag: true,
    tagMaxChars: 4,
    showProgressBar: false,
    showPageChip: false,
    categoryChipVisualDensity: _compactCategoryChipVisualDensity,
    categoryChipLabelPadding: EdgeInsets.symmetric(horizontal: 4),
    categoryFilterBarPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  );

  static ThreadCardDensityTokens forDensity(ListDensity density) {
    switch (density) {
      case ListDensity.compact:
        return compact;
      case ListDensity.standard:
        return standard;
    }
  }
}

/// 从当前用户的阅读历史列表中查出指定 tid 的记录（无则 null）。
class ThreadCard extends ConsumerWidget {
  const ThreadCard({
    super.key,
    required this.thread,
    this.onOpenThread,
    this.onTypeFilter,
    this.selectedTypeId,
    this.selected = false,
  });
  final Thread thread;

  /// Overrides normal route navigation for the forum desktop detail pane.
  final ThreadOpenCallback? onOpenThread;

  /// 点击主题分类筛选；再点已选分类传 `null` 取消。
  final ThreadTypeFilterCallback? onTypeFilter;

  /// 与版块顶栏 [FilterChip] 同步的当前筛选 typeId。
  final String? selectedTypeId;
  final bool selected;

  int _calcTotalPages(
    int replies, {
    int perPage = S1Constants.postsPerPageFallback,
  }) {
    return calcThreadTotalPages(replies, perPage: perPage);
  }

  /// 点击：按阅读记录解析目标页（续读 / 已读落末页 / 有新回复落新页）。
  void _handleTap(BuildContext context, WidgetRef ref) {
    S1Haptics.selection();
    if (onOpenThread != null) {
      final record = ref.read(readingRecordProvider(thread.tid));
      final targetPage = record?.resolveOpenPage(thread.replies);
      onOpenThread!(
        ResumeThread(thread.tid),
        resumePageHint:
            targetPage != null && targetPage > 1 ? targetPage : null,
      );
      return;
    }
    final record = ref.read(readingRecordProvider(thread.tid));
    context.push(
      buildThreadDetailPath(
        thread.tid,
        record: record,
        liveTotalReplies: thread.replies,
      ),
    );
  }

  void _showPageSheet(BuildContext context) {
    final totalPages = _calcTotalPages(thread.replies);
    if (totalPages <= 1) {
      if (onOpenThread != null) {
        onOpenThread!(ThreadPage(thread.tid, 1));
        return;
      }
      context.push(
        ThreadRouteCodec.encodePath(ThreadPage(thread.tid, 1)),
      );
      return;
    }

    const perPage = S1Constants.postsPerPageFallback;
    showPagePickerSheet(
      context: context,
      totalPages: totalPages,
      subtitle: thread.subject,
      pageItemLabelBuilder: (page) {
        final start = (page - 1) * perPage + 1;
        final end = page * perPage;
        return '第 $start - $end 楼';
      },
      onPageSelected: (page) {
        if (onOpenThread != null) {
          onOpenThread!(ThreadPage(thread.tid, page));
          return;
        }
        context.push(
          ThreadRouteCodec.encodePath(ThreadPage(thread.tid, page)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final density = ref.watch(
      settingsProvider.select((s) => s.threadListDensity),
    );
    final tokens = ThreadCardDensityTokens.forDensity(density);
    final hasTag = thread.typeName != null && thread.typeName!.isNotEmpty;
    final isSticky = thread.isSticky;
    final totalPages = _calcTotalPages(thread.replies);
    final onCardPrimary = selected
        ? scheme.onSecondaryContainer
        : isSticky
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    final onCardSecondary = selected
        ? scheme.onSecondaryContainer.withValues(alpha: S1Alpha.strong)
        : isSticky
            ? scheme.onPrimaryContainer.withValues(alpha: S1Alpha.strong)
            : scheme.onSurfaceVariant;
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: onCardSecondary,
      height: 1.2,
    );
    final typeId = thread.typeId;
    final canFilterType =
        onTypeFilter != null && typeId != null && typeId.isNotEmpty;

    return Semantics(
      selected: selected,
      button: true,
      label: thread.subject,
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: tokens.cardMarginVertical,
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: selected
            ? scheme.secondaryContainer
            : isSticky
                ? scheme.primaryContainer
                : S1Surface.card(scheme),
        shape: S1Shape.cardShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _handleTap(context, ref),
          borderRadius: S1Shape.medium,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: tokens.cardPaddingVertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleLine(
                  subject: thread.subject,
                  isSticky: isSticky,
                  hasTag: hasTag,
                  tagName: thread.typeName,
                  typeId: typeId,
                  selectedTypeId: selectedTypeId,
                  onTypeFilter: canFilterType ? onTypeFilter : null,
                  isOnTintedCard: isSticky || selected,
                  titleColor: onCardPrimary,
                  pinColor: onCardSecondary,
                  scheme: scheme,
                  textTheme: textTheme,
                  tokens: tokens,
                ),
                SizedBox(height: tokens.titleMetaGap),
                _MetaLine(
                  author: thread.author,
                  time: formatTimeAgo(thread.dateline),
                  views: formatCount(thread.views),
                  replyCount: thread.replies,
                  totalPages: totalPages,
                  metaStyle: metaStyle,
                  scheme: scheme,
                  authorColor: onCardPrimary,
                  secondaryColor: onCardSecondary,
                  showPageChip: tokens.showPageChip,
                  onPageTap: tokens.showPageChip && totalPages > 1
                      ? () => _showPageSheet(context)
                      : null,
                  tid: thread.tid,
                  liveTotalReplies: thread.replies,
                ),
                if (tokens.showProgressBar)
                  _ReadingProgressBar(
                    tid: thread.tid,
                    liveTotalReplies: thread.replies,
                    progressTop: tokens.progressTop,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  阅读进度：标准密度 2px 细条（文案已并入 meta 回复数）
// ═══════════════════════════════════════════════════════════

class _ReadingProgressBar extends ConsumerWidget {
  const _ReadingProgressBar({
    required this.tid,
    required this.liveTotalReplies,
    required this.progressTop,
  });
  final String tid;
  final int liveTotalReplies;
  final double progressTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(readingRecordProvider(tid));
    if (record == null || record.progressAt(liveTotalReplies) <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isFinished = record.isFinishedAt(liveTotalReplies);
    if (isFinished) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: progressTop),
      child: ClipRRect(
        borderRadius: S1Shape.extraSmall,
        child: LinearProgressIndicator(
          value: record.progressAt(liveTotalReplies),
          minHeight: 2,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            scheme.primary.withValues(alpha: S1Alpha.strong),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  标题行：[置顶图标] [分类标签] 标题文字
// ═══════════════════════════════════════════════════════════

class _TitleLine extends StatelessWidget {
  const _TitleLine({
    required this.subject,
    required this.isSticky,
    required this.hasTag,
    required this.tagName,
    required this.typeId,
    required this.selectedTypeId,
    required this.onTypeFilter,
    required this.isOnTintedCard,
    required this.titleColor,
    required this.pinColor,
    required this.scheme,
    required this.textTheme,
    required this.tokens,
  });
  final String subject;
  final bool isSticky;
  final bool hasTag;
  final String? tagName;
  final String? typeId;
  final String? selectedTypeId;
  final ThreadTypeFilterCallback? onTypeFilter;
  final bool isOnTintedCard;
  final Color titleColor;
  final Color pinColor;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ThreadCardDensityTokens tokens;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      subject,
      style: textTheme.titleSmall?.copyWith(
        color: titleColor,
        height: tokens.titleHeight,
        fontWeight: isSticky ? FontWeight.bold : null,
      ),
      maxLines: tokens.titleMaxLines,
      overflow: TextOverflow.ellipsis,
    );

    final pin =
        isSticky ? Icon(Icons.push_pin, size: 13, color: pinColor) : null;

    final fullTagName = tagName ?? '';
    final displayTag =
        hasTag ? _truncateTagLabel(fullTagName, tokens.tagMaxChars) : null;

    final tag = hasTag && displayTag != null
        ? _CategoryTag(
            label: displayTag,
            fullLabel: fullTagName,
            typeId: typeId,
            selected: typeId != null && selectedTypeId == typeId,
            onTypeFilter: onTypeFilter,
            isOnTintedCard: isOnTintedCard,
            lowEmphasis: tokens.titleMaxLines > 1,
            chipVisualDensity: tokens.categoryChipVisualDensity,
            chipLabelPadding: tokens.categoryChipLabelPadding,
            scheme: scheme,
          )
        : null;

    if (tokens.inlineTag) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pin != null) ...[
            Padding(
              padding: EdgeInsets.only(
                top: (tokens.titleHeight * 14 - 13) / 2,
              ),
              child: pin,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(child: title),
          if (tag != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: tag,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tag != null) ...[
          tag,
          const SizedBox(height: 4),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pin != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: (tokens.titleHeight * 14 - 13) / 2,
                ),
                child: pin,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: title),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  信息行：作者 · 时间                               浏览 回复 [页数]
//
//  左侧 Flexible（可压缩，靠左）
//  右侧 统计信息与页码（靠右）
// ═══════════════════════════════════════════════════════════

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.author,
    required this.time,
    required this.views,
    required this.replyCount,
    required this.totalPages,
    required this.metaStyle,
    required this.scheme,
    required this.authorColor,
    required this.secondaryColor,
    required this.tid,
    required this.liveTotalReplies,
    required this.showPageChip,
    this.onPageTap,
  });
  final String author;
  final String time;
  final String views;
  final int replyCount;
  final int totalPages;
  final TextStyle? metaStyle;
  final ColorScheme scheme;
  final Color authorColor;
  final Color secondaryColor;
  final VoidCallback? onPageTap;
  final String tid;
  final int liveTotalReplies;
  final bool showPageChip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              style: metaStyle,
              children: [
                TextSpan(
                  text: author,
                  style: metaStyle?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: authorColor,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: time,
                    style: metaStyle?.copyWith(
                      color: secondaryColor,
                    ),
                  ),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MetaStat(
                  icon: Icons.visibility_outlined,
                  value: views,
                  color: secondaryColor,
                  textStyle: metaStyle,
                ),
                const SizedBox(width: 8),
                _ReplyMetaStat(
                  replyCount: replyCount,
                  tid: tid,
                  liveTotalReplies: liveTotalReplies,
                  color: secondaryColor,
                  textStyle: metaStyle,
                  scheme: scheme,
                ),
                if (showPageChip && totalPages > 1 && onPageTap != null) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    label: CompactLabel.text(
                      '$totalPages页',
                      style: CompactLabel.style(
                        context,
                        base: metaStyle,
                        color: secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: scheme.surfaceContainerHighest,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    onPressed: onPageTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplyMetaStat extends ConsumerWidget {
  const _ReplyMetaStat({
    required this.replyCount,
    required this.tid,
    required this.liveTotalReplies,
    required this.color,
    required this.textStyle,
    required this.scheme,
  });

  final int replyCount;
  final String tid;
  final int liveTotalReplies;
  final Color color;
  final TextStyle? textStyle;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(readingRecordProvider(tid));
    final base = formatFullCount(replyCount);
    final progress = record?.progressAt(liveTotalReplies) ?? 0;
    final isFinished = record != null && record.isFinishedAt(liveTotalReplies);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 0.5),
          child: Icon(Icons.chat_bubble_outline, size: 12, color: color),
        ),
        const SizedBox(width: 2),
        CompactLabel.text(
          base,
          style: CompactLabel.style(
            context,
            base: textStyle,
            color: color,
          ),
        ),
        if (record != null && progress > 0) ...[
          const SizedBox(width: 4),
          _ReadingStateBadge(
            isFinished: isFinished,
            lastReadFloor: record.lastReadFloor,
            textStyle: textStyle,
            scheme: scheme,
          ),
        ],
      ],
    );
  }
}

/// 阅读进度角标：与回复数分列，避免 `19,001#18980` 连成一片。
class _ReadingStateBadge extends StatelessWidget {
  const _ReadingStateBadge({
    required this.isFinished,
    required this.lastReadFloor,
    required this.textStyle,
    required this.scheme,
  });

  final bool isFinished;
  final int lastReadFloor;
  final TextStyle? textStyle;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (isFinished) {
      return Badge(
        label: CompactLabel.text(
          '已读',
          style: CompactLabel.style(
            context,
            base: textStyle,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      );
    }

    return Badge(
      label: CompactLabel.text(
        '#${formatFullCount(lastReadFloor)}',
        style: CompactLabel.style(
          context,
          base: textStyle,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    );
  }
}

class _MetaStat extends StatelessWidget {
  const _MetaStat({
    required this.icon,
    required this.value,
    required this.color,
    required this.textStyle,
  });

  final IconData icon;
  final String value;
  final Color color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        CompactLabel.text(
          value,
          style: CompactLabel.style(
            context,
            base: textStyle,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  分类标签（可筛选 FilterChip / 只读 Chip）
// ═══════════════════════════════════════════════════════════

String _truncateTagLabel(String label, int? maxChars) {
  if (maxChars == null || label.length <= maxChars) return label;
  return label.substring(0, maxChars);
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({
    required this.label,
    required this.fullLabel,
    required this.typeId,
    required this.selected,
    required this.onTypeFilter,
    required this.isOnTintedCard,
    required this.lowEmphasis,
    required this.chipVisualDensity,
    required this.chipLabelPadding,
    required this.scheme,
  });
  final String label;
  final String fullLabel;
  final String? typeId;
  final bool selected;
  final ThreadTypeFilterCallback? onTypeFilter;
  final bool isOnTintedCard;
  final bool lowEmphasis;
  final VisualDensity chipVisualDensity;
  final EdgeInsetsGeometry chipLabelPadding;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = CompactLabel.style(
      context,
      fontWeight: lowEmphasis ? FontWeight.w500 : FontWeight.w600,
      color: lowEmphasis ? scheme.onSurfaceVariant : null,
    );

    if (onTypeFilter != null && typeId != null) {
      final chipBg = selected
          ? scheme.secondaryContainer
          : lowEmphasis
              ? scheme.surfaceContainerHigh
              : isOnTintedCard
                  ? S1Surface.card(scheme)
                  : scheme.surfaceContainerHighest;

      final chip = FilterChip(
        label: CompactLabel.text(label, style: labelStyle),
        selected: selected,
        showCheckmark: false,
        backgroundColor: chipBg,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : scheme.outline.withValues(alpha: S1Alpha.subtle),
        ),
        visualDensity: chipVisualDensity,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: chipLabelPadding,
        padding: EdgeInsets.zero,
        onSelected: (nextSelected) {
          S1Haptics.selection();
          if (nextSelected) {
            onTypeFilter!(typeId);
          } else {
            onTypeFilter!(null);
          }
        },
      );
      if (fullLabel != label) {
        return Tooltip(message: fullLabel, child: chip);
      }
      return chip;
    }

    return Chip(
      label: CompactLabel.text(
        label,
        style: CompactLabel.style(
          context,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide.none,
      labelPadding: chipLabelPadding,
      visualDensity: chipVisualDensity,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
