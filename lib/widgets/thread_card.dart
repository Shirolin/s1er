import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/constants.dart';
import '../models/reading_record.dart';
import '../models/thread.dart';
import '../providers/reading_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import 'page_picker_sheet.dart';

/// 从当前用户的阅读历史列表中查出指定 tid 的记录（无则 null）。
ReadingRecord? _recordFor(List<ReadingRecord> list, String tid) {
  for (final r in list) {
    if (r.tid == tid) return r;
  }
  return null;
}

class ThreadCard extends ConsumerWidget {

  const ThreadCard({super.key, required this.thread});
  final Thread thread;

  int _calcTotalPages(int replies,
      {int perPage = S1Constants.postsPerPageFallback,}) {
    final totalPosts = replies + 1;
    return (totalPosts / perPage).ceil().clamp(1, 9999);
  }

  /// 点击：有未读完记录则续读到上次页码，否则从第一页打开。
  void _handleTap(BuildContext context, WidgetRef ref) {
    final record = _recordFor(ref.read(readingHistoryProvider), thread.tid);
    if (record != null && !record.isFinished && record.lastReadPage > 1) {
      context.push('/thread/${thread.tid}?page=${record.lastReadPage}');
    } else {
      context.push('/thread/${thread.tid}');
    }
  }

  void _showPageSheet(BuildContext context) {
    final totalPages = _calcTotalPages(thread.replies);
    if (totalPages <= 1) {
      context.push('/thread/${thread.tid}');
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
        context.push(
          page == 1
              ? '/thread/${thread.tid}'
              : '/thread/${thread.tid}?page=$page',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasTag = thread.typeName != null && thread.typeName!.isNotEmpty;
    final isSticky = thread.isSticky;
    final totalPages = _calcTotalPages(thread.replies);
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.2,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isSticky
          ? scheme.primaryContainer
          : scheme.surfaceContainerLow,
      shape: S1Shape.cardShape,
      child: InkWell(
        onTap: () => _handleTap(context, ref),
        borderRadius: S1Shape.medium,
        child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              ),
              const SizedBox(height: 8),
              _MetaLine(
                author: thread.author,
                time: formatTimeAgo(thread.dateline),
                views: formatCount(thread.views),
                replies: formatCount(thread.replies),
                totalPages: totalPages,
                metaStyle: metaStyle,
                scheme: scheme,
                onPageTap: totalPages > 1
                    ? () => _showPageSheet(context)
                    : null,
              ),
              _ReadingProgressBar(tid: thread.tid),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  阅读进度指示器：无记录时不占位
// ═══════════════════════════════════════════════════════════

class _ReadingProgressBar extends ConsumerWidget {
  const _ReadingProgressBar({required this.tid});
  final String tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 从历史列表按 tid 选取，随 readingHistoryProvider 刷新而实时更新。
    final record = ref.watch(
      readingHistoryProvider.select((list) => _recordFor(list, tid)),
    );
    if (record == null || record.progress <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFinished = record.isFinished;
    final accent = isFinished ? scheme.onSurfaceVariant : scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
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
                value: record.progress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFinished
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
                      : scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isFinished ? '已读' : 'P${record.lastReadPage}',
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
  });
  final String subject;
  final bool isSticky;
  final bool hasTag;
  final String? tagName;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTag) ...[
          _CategoryTag(
            label: tagName!,
            color: scheme.onSecondaryContainer,
            bgColor: scheme.secondaryContainer,
          ),
          const SizedBox(height: 4),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSticky) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.push_pin, size: 13, color: scheme.primary),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                subject,
                style: textTheme.titleSmall?.copyWith(
                  height: 1.45,
                  fontWeight: isSticky ? FontWeight.bold : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
        // ── 右侧：统计（固定） + 页码（如果存在） ──
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
