import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/reading_record.dart';
import '../providers/forum_name_provider.dart';
import '../providers/reading_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/thread_navigation.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_desktop_scaffold.dart';

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(readingHistoryProvider.select((s) => s.records));
    final fidToForumName = ref.watch(fidToForumNameMapProvider);

    return S1DesktopScaffold(
      highlightedTab: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('阅读历史'),
          actions: [
            if (records.isNotEmpty)
              IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _confirmClearAll(context, ref),
              ),
          ],
        ),
        body: records.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: records.length,
                itemBuilder: (context, index) => _HistoryTile(
                  record: records[index],
                  forumName: fidToForumName[records[index].fid],
                ),
              ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '清空阅读历史',
      content: '将删除当前账号的全部阅读记录，此操作不可恢复。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(readingHistoryProvider.notifier).clearAll();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '暂无阅读记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({
    required this.record,
    this.forumName,
  });
  final ReadingRecord record;
  final String? forumName;

  void _open(BuildContext context) {
    context.push(
      buildThreadDetailPath(
        record.tid,
        record: record,
        liveTotalReplies: record.totalReplies,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFinished = record.isFinished;
    final accent = isFinished ? scheme.onSurfaceVariant : scheme.primary;

    final metaParts = <String>[
      if (record.author.isNotEmpty) record.author,
      if (forumName != null && forumName!.isNotEmpty) forumName!,
      formatTimeAgo(record.lastReadAt ~/ 1000),
      if (record.readCount > 1) '读过 ${record.readCount} 次',
    ];

    return Dismissible(
      key: ValueKey('reading_history_${record.tid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) =>
          ref.read(readingHistoryProvider.notifier).delete(record.tid),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 0,
        color: S1Surface.card(scheme),
        shape: S1Shape.cardShape,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: S1Shape.medium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.subject.isEmpty ? '(无标题)' : record.subject,
                  style: textTheme.titleSmall?.copyWith(height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  metaParts.join(' · '),
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isFinished ? Icons.check_circle_outline : Icons.schedule,
                      size: 13,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: S1Shape.extraSmall,
                        child: LinearProgressIndicator(
                          value: record.progress,
                          minHeight: 4,
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
                    const SizedBox(width: 8),
                    Text(
                      isFinished
                          ? '已读'
                          : '#${record.lastReadFloor}/${record.totalPosts}',
                      style: textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
