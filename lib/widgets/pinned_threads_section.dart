import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pinned_thread.dart';
import '../providers/pinned_threads_provider.dart';
import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';
import 's1_adaptive_sheet.dart';

class PinnedThreadsSection extends ConsumerStatefulWidget {
  const PinnedThreadsSection({
    super.key,
    required this.threads,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<PinnedThread> threads;
  final EdgeInsetsGeometry margin;

  @override
  ConsumerState<PinnedThreadsSection> createState() =>
      _PinnedThreadsSectionState();
}

class _PinnedThreadsSectionState extends ConsumerState<PinnedThreadsSection> {
  bool _expanded = true;
  bool _managing = false;

  void _showPinActions(BuildContext context, PinnedThread thread) {
    S1Haptics.selection();

    showS1ActionSheet<void>(
      context: context,
      builder: (sheetContext) {
        return S1AdaptiveSheetScaffold(
          title: thread.title,
          children: [
            S1AdaptiveActionTile(
              icon: Icons.push_pin_outlined,
              label: '取消置顶',
              destructive: true,
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(pinnedThreadsProvider.notifier).unpin(thread.tid);
                if (mounted) {
                  S1SnackBar.show(context, message: '已取消置顶');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.threads.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final threads = widget.threads;

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
                  Icon(
                    Icons.push_pin,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '置顶帖子',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _managing ? Icons.check : Icons.reorder,
                      size: 20,
                      color:
                          _managing ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    tooltip: _managing ? '完成' : '管理',
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      S1Haptics.selection();
                      setState(() {
                        _managing = !_managing;
                        if (_managing) _expanded = true;
                      });
                    },
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
                      setState(() {
                        _expanded = !_expanded;
                        if (!_expanded) _managing = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && _managing)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: threads.length,
              onReorderItem: (oldIndex, newIndex) {
                final list = List<PinnedThread>.from(threads);
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                ref.read(pinnedThreadsProvider.notifier).reorder(list);
              },
              itemBuilder: (context, index) {
                final thread = threads[index];
                return ListTile(
                  key: ValueKey(thread.tid),
                  dense: true,
                  title: Text(
                    thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.drag_handle),
                );
              },
            )
          else if (_expanded)
            Column(
              children: [
                for (final thread in threads)
                  InkWell(
                    onTap: () {
                      S1Haptics.selection();
                      context.push('/thread/${thread.tid}');
                    },
                    onLongPress: () => _showPinActions(context, thread),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              thread.title,
                              style: textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              ],
            ),
        ],
      ),
    );
  }
}
