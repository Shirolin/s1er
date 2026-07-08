import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/thread.dart';
import '../utils/format_utils.dart';

class ThreadCard extends StatelessWidget {

  const ThreadCard({super.key, required this.thread});
  final Thread thread;

  int _calcTotalPages(int replies, {int perPage = 40}) {
    final totalPosts = replies + 1;
    return (totalPosts / perPage).ceil().clamp(1, 9999);
  }

  void _showPageSheet(BuildContext context) {
    final totalPages = _calcTotalPages(thread.replies);
    if (totalPages <= 1) {
      context.push('/thread/${thread.tid}');
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _ThreadPageSheet(
        outerContext: context,
        tid: thread.tid,
        subject: thread.subject,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSticky
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: isSticky ? 0.8 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/thread/${thread.tid}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              const SizedBox(height: 6),
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
            ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSticky) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.push_pin, size: 13, color: scheme.primary),
          ),
          const SizedBox(width: 4),
        ],
        if (hasTag) ...[
          _CategoryTag(
            label: tagName!,
            color: scheme.primary,
            bgColor: scheme.primaryContainer.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            subject,
            style: textTheme.titleSmall?.copyWith(
              height: 1.4,
              fontWeight: isSticky ? FontWeight.bold : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  信息行：作者 · 时间 …… 浏览 回复 [页数]
//
//  左侧 Flexible（可压缩）   右侧 min（固定宽度）
//  超长作者名自动 ellipsis    数字已缩写，不会溢出
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
      children: [
        // ── 左侧：作者 + 时间（可压缩） ──
        Flexible(
          child: Text.rich(
            TextSpan(
              style: metaStyle,
              children: [
                TextSpan(text: author),
                if (time.isNotEmpty) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: time,
                    style: metaStyle?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
        // ── 右侧：统计（固定，不压缩） ──
        Text.rich(
          TextSpan(
            style: metaStyle,
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.visibility_outlined, size: 12, color: scheme.onSurfaceVariant),
              ),
              const TextSpan(text: ' '),
              TextSpan(text: views),
              const TextSpan(text: '  '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.chat_bubble_outline, size: 11, color: scheme.onSurfaceVariant),
              ),
              const TextSpan(text: ' '),
              TextSpan(text: replies),
            ],
          ),
        ),
        if (totalPages > 1) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onPageTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$totalPages页',
                style: metaStyle?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onTertiaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  页码选择 BottomSheet
// ═══════════════════════════════════════════════════════════

class _ThreadPageSheet extends StatelessWidget {
  const _ThreadPageSheet({
    required this.outerContext,
    required this.tid,
    required this.subject,
    required this.totalPages,
  });
  final BuildContext outerContext;
  final String tid;
  final String subject;
  final int totalPages;

  static const int _perPage = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('选择页码', style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '共 $totalPages 页',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: totalPages,
                itemBuilder: (ctx, index) {
                  final page = index + 1;
                  final startPost = (page - 1) * _perPage + 1;
                  final endPost = page * _perPage;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      GoRouter.of(outerContext).push(
                        page == 1
                            ? '/thread/$tid'
                            : '/thread/$tid?page=$page',
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$page',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '第 $startPost - $endPost 楼',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
