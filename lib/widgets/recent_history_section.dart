import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/reading_record.dart';
import '../providers/forum_name_provider.dart';
import '../providers/reading_history_provider.dart';
import '../theme/s1_haptics.dart';
import '../utils/format_utils.dart';
import '../utils/thread_navigation.dart';

/// 首页论坛列表上的最近浏览：固定 [kRecentHistoryPreviewCount] 条，标题行进入完整历史。
class RecentHistorySection extends ConsumerStatefulWidget {
  const RecentHistorySection({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final EdgeInsetsGeometry margin;

  @override
  ConsumerState<RecentHistorySection> createState() =>
      _RecentHistorySectionState();
}

class _RecentHistorySectionState extends ConsumerState<RecentHistorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recentReadingPreviewProvider);
    if (records.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final forumNames = ref.watch(fidToForumNameMapProvider);

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '最近浏览',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(32, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      S1Haptics.selection();
                      context.push('/reading-history');
                    },
                    child: const Text('全部'),
                  ),
                  IconButton(
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: _expanded ? '收起' : '展开',
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      S1Haptics.selection();
                      setState(() => _expanded = !_expanded);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            for (final record in records)
              _RecentHistoryTile(
                record: record,
                forumName: forumNames[record.fid],
              ),
        ],
      ),
    );
  }
}

class _RecentHistoryTile extends StatelessWidget {
  const _RecentHistoryTile({
    required this.record,
    this.forumName,
  });

  final ReadingRecord record;
  final String? forumName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final finished = record.isFinished;
    final accent = finished ? scheme.onSurfaceVariant : scheme.primary;
    final time = formatTimeAgo(record.lastReadAt ~/ 1000);
    final meta = [
      if (forumName != null && forumName!.isNotEmpty) forumName!,
      if (time.isNotEmpty) time,
    ].join(' · ');
    final progress =
        finished ? '已读' : '#${record.lastReadFloor}/${record.totalPosts}';
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final title = record.subject.isEmpty ? '(无标题)' : record.subject;

    return InkWell(
      onTap: () {
        S1Haptics.selection();
        context.push(
          buildThreadDetailPath(
            record.tid,
            record: record,
            liveTotalReplies: record.totalReplies,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text.rich(
                      TextSpan(
                        style: metaStyle,
                        children: [
                          if (meta.isNotEmpty) TextSpan(text: '$meta · '),
                          TextSpan(
                            text: progress,
                            style: metaStyle?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
