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
    required this.inlineProgress,
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

  /// When true, reading progress is a meta-row badge (no dedicated bar row).
  final bool inlineProgress;

  static const standard = ThreadCardDensityTokens(
    cardMarginVertical: 4,
    cardPaddingVertical: 8,
    titleMetaGap: 8,
    titleMaxLines: 2,
    titleHeight: 1.45,
    progressTop: 6,
    inlineTag: false,
    tagMaxChars: null,
    inlineProgress: false,
  );

  static const compact = ThreadCardDensityTokens(
    cardMarginVertical: 2,
    cardPaddingVertical: 5,
    titleMetaGap: 4,
    titleMaxLines: 1,
    titleHeight: 1.3,
    progressTop: 4,
    inlineTag: true,
    tagMaxChars: 4,
    inlineProgress: true,
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
    this.selected = false,
  });
  final Thread thread;

  /// Overrides normal route navigation for the forum desktop detail pane.
  final ThreadOpenCallback? onOpenThread;
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
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.2,
    );

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
                  scheme: scheme,
                  textTheme: textTheme,
                  tokens: tokens,
                ),
                SizedBox(height: tokens.titleMetaGap),
                _MetaLine(
                  author: thread.author,
                  time: formatTimeAgo(thread.dateline),
                  views: formatCount(thread.views),
                  replies: formatCount(thread.replies),
                  totalPages: totalPages,
                  metaStyle: metaStyle,
                  scheme: scheme,
                  onPageTap:
                      totalPages > 1 ? () => _showPageSheet(context) : null,
                  tid: thread.tid,
                  liveTotalReplies: thread.replies,
                  showInlineProgress: tokens.inlineProgress,
                ),
                if (!tokens.inlineProgress)
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
//  阅读进度指示器：无记录时不占位（仅标准密度）
// ═══════════════════════════════════════════════════════════

String? _readingProgressLabel({
  required int lastReadFloor,
  required int liveTotalReplies,
  required bool isFinished,
}) {
  if (isFinished) return '已读';
  final liveTotalPosts = liveTotalReplies + 1;
  return '#$lastReadFloor/$liveTotalPosts';
}

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
    // 按 tid 订阅阅读记录，仅在对应记录变化时重建。
    final record = ref.watch(readingRecordProvider(tid));
    if (record == null || record.progressAt(liveTotalReplies) <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFinished = record.isFinishedAt(liveTotalReplies);
    final accent = isFinished ? scheme.onSurfaceVariant : scheme.primary;
    final label = _readingProgressLabel(
      lastReadFloor: record.lastReadFloor,
      liveTotalReplies: liveTotalReplies,
      isFinished: isFinished,
    )!;

    return Padding(
      padding: EdgeInsets.only(top: progressTop),
      child: Row(
        children: [
          Icon(
            isFinished ? Icons.check_circle_outline : Icons.schedule,
            size: 12,
            color: accent,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: S1Shape.extraSmall,
              child: LinearProgressIndicator(
                value: record.progressAt(liveTotalReplies),
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFinished
                      ? scheme.onSurfaceVariant
                          .withValues(alpha: S1Alpha.medium)
                      : scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact density: reading progress as a meta-row chip (no extra bar row).
class _CompactReadingBadge extends ConsumerWidget {
  const _CompactReadingBadge({
    required this.tid,
    required this.liveTotalReplies,
    required this.metaStyle,
  });

  final String tid;
  final int liveTotalReplies;
  final TextStyle? metaStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(readingRecordProvider(tid));
    if (record == null || record.progressAt(liveTotalReplies) <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isFinished = record.isFinishedAt(liveTotalReplies);
    final label = _readingProgressLabel(
      lastReadFloor: record.lastReadFloor,
      liveTotalReplies: liveTotalReplies,
      isFinished: isFinished,
    )!;

    final Color fg;
    final Color bg;
    if (isFinished) {
      fg = scheme.onSurfaceVariant;
      bg = scheme.surfaceContainerHighest;
    } else {
      fg = scheme.onPrimaryContainer;
      bg = scheme.primaryContainer;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Chip(
        label: CompactLabel.text(
          label,
          style: CompactLabel.style(
            context,
            base: metaStyle,
            color: fg,
            fontWeight: FontWeight.w500,
          ),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: bg,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
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
    required this.scheme,
    required this.textTheme,
    required this.tokens,
  });
  final String subject;
  final bool isSticky;
  final bool hasTag;
  final String? tagName;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ThreadCardDensityTokens tokens;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      subject,
      style: textTheme.titleSmall?.copyWith(
        height: tokens.titleHeight,
        fontWeight: isSticky ? FontWeight.bold : null,
      ),
      maxLines: tokens.titleMaxLines,
      overflow: TextOverflow.ellipsis,
    );

    final pin = isSticky
        ? Icon(Icons.push_pin, size: 13, color: scheme.primary)
        : null;

    final tag = hasTag
        ? _CategoryTag(
            label: _truncateTagLabel(tagName!, tokens.tagMaxChars),
            color: scheme.onSecondaryContainer,
            bgColor: scheme.secondaryContainer,
          )
        : null;

    if (tokens.inlineTag) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (tag != null) ...[
            tag,
            const SizedBox(width: 6),
          ],
          if (pin != null) ...[
            pin,
            const SizedBox(width: 4),
          ],
          Expanded(child: title),
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
    required this.replies,
    required this.totalPages,
    required this.metaStyle,
    required this.scheme,
    required this.tid,
    required this.liveTotalReplies,
    required this.showInlineProgress,
    this.onPageTap,
  });
  final String author;
  final String time;
  final String views;
  final String replies;
  final int totalPages;
  final TextStyle? metaStyle;
  final ColorScheme scheme;
  final VoidCallback? onPageTap;
  final String tid;
  final int liveTotalReplies;
  final bool showInlineProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // ── 左侧：作者 + 时间（可压缩） ──
        Flexible(
          child: Text.rich(
            TextSpan(
              style: metaStyle,
              children: [
                TextSpan(
                  text: author,
                  style: metaStyle?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: time,
                    style: metaStyle?.copyWith(
                      color: scheme.onSurfaceVariant,
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
        // ── 右侧：统计 + 阅读进度徽标（紧凑） + 页码 ──
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _MetaStat(
              icon: Icons.visibility_outlined,
              value: views,
              color: scheme.onSurfaceVariant,
              textStyle: metaStyle,
            ),
            const SizedBox(width: 8),
            _MetaStat(
              icon: Icons.chat_bubble_outline,
              value: replies,
              color: scheme.onSurfaceVariant,
              textStyle: metaStyle,
              iconOffset: const Offset(0, 0.5),
            ),
            if (showInlineProgress)
              _CompactReadingBadge(
                tid: tid,
                liveTotalReplies: liveTotalReplies,
                metaStyle: metaStyle,
              ),
            if (totalPages > 1) ...[
              const SizedBox(width: 8),
              ActionChip(
                label: CompactLabel.text(
                  '$totalPages页',
                  style: CompactLabel.style(
                    context,
                    base: metaStyle,
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: scheme.secondaryContainer,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                onPressed: onPageTap,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _MetaStat extends StatelessWidget {
  const _MetaStat({
    required this.icon,
    required this.value,
    required this.color,
    required this.textStyle,
    this.iconOffset = Offset.zero,
  });

  final IconData icon;
  final String value;
  final Color color;
  final TextStyle? textStyle;
  final Offset iconOffset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: iconOffset,
          child: Icon(icon, size: 12, color: color),
        ),
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
//  分类标签
// ═══════════════════════════════════════════════════════════

String _truncateTagLabel(String label, int? maxChars) {
  if (maxChars == null || label.length <= maxChars) return label;
  return label.substring(0, maxChars);
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({
    required this.label,
    required this.color,
    required this.bgColor,
  });
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: CompactLabel.text(
        label,
        style: CompactLabel.style(
          context,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: bgColor,
      side: BorderSide.none,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
