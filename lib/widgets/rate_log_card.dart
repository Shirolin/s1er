import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rate_log.dart';
import '../providers/thread_rate_logs_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'user_profile_sheet.dart';
import 's1_click_region.dart';

class RateLogCard extends ConsumerStatefulWidget {
  const RateLogCard({super.key, required this.tid, required this.pid});
  final String tid;
  final String pid;

  @override
  ConsumerState<RateLogCard> createState() => _RateLogCardState();
}

class _RateLogCardState extends ConsumerState<RateLogCard> {
  bool _expanded = false;
  bool _isLocalExpanded = false;
  bool _isLoadingFull = false;

  // 默认初始显示的条数，对齐服务器内联输出上限
  static const int _initialDisplayCount = 20;
  static const int _collapsedPreviewCount = 3;

  Future<void> _handleLoadFull() async {
    setState(() => _isLoadingFull = true);
    try {
      await ref
          .read(threadRateLogsProvider(widget.tid).notifier)
          .loadFullRateLog(widget.pid);
      if (mounted) setState(() => _isLocalExpanded = true);
    } finally {
      if (mounted) setState(() => _isLoadingFull = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rateLog = ref.watch(rateLogProvider((widget.tid, widget.pid)));
    if (rateLog == null || rateLog.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isPositive = rateLog.totalScore >= 0;
    final accentColor = isPositive ? scheme.primary : scheme.error;

    // 1. 判断服务器是否截断了数据
    final isServerTruncated = rateLog.entries.length < rateLog.participantCount;

    // 2. 决定当前 UI 上展示哪些条目
    final List<RateLog> displayEntries;
    if (_isLocalExpanded || rateLog.entries.length <= _initialDisplayCount) {
      displayEntries = rateLog.entries;
    } else {
      displayEntries = rateLog.entries.take(_initialDisplayCount).toList();
    }

    // 3. 判断是否需要显示“更多”按钮
    final hasMoreLocally = rateLog.entries.length > displayEntries.length;
    final needsMoreButton = hasMoreLocally || isServerTruncated;
    final collapsedEntries =
        rateLog.entries.take(_collapsedPreviewCount).toList();
    final totalEntryCount = rateLog.participantCount > rateLog.entries.length
        ? rateLog.participantCount
        : rateLog.entries.length;
    final collapsedHiddenCount = totalEntryCount - collapsedEntries.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: S1Surface.nestedPanel(scheme),
        elevation: 0,
        shape: S1Shape.cardShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  totalScore: rateLog.totalScore,
                  participantCount: rateLog.participantCount,
                  accentColor: accentColor,
                  expanded: _expanded,
                  hiddenCount: collapsedHiddenCount,
                ),
                if (!_expanded && collapsedEntries.isNotEmpty)
                  _EntriesPanel(
                    scheme: scheme,
                    children: [
                      ...collapsedEntries.map(
                        (entry) => _EntryRow(
                          entry: entry,
                          accentColor: accentColor,
                        ),
                      ),
                    ],
                  ),
                if (_expanded)
                  _EntriesPanel(
                    scheme: scheme,
                    children: [
                      ...displayEntries.map(
                        (entry) => _EntryRow(
                          entry: entry,
                          accentColor: accentColor,
                        ),
                      ),
                      if (needsMoreButton)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Center(
                            child: _isLoadingFull
                                ? const SizedBox(
                                    height: 32,
                                    width: 32,
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : TextButton(
                                    onPressed: () {
                                      if (hasMoreLocally) {
                                        setState(() => _isLocalExpanded = true);
                                      } else if (isServerTruncated) {
                                        _handleLoadFull();
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      hasMoreLocally
                                          ? '显示全部本地记录 (共${rateLog.entries.length}条)'
                                          : '加载完整评分历史 (共${rateLog.participantCount}人)',
                                    ),
                                  ),
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

class _EntriesPanel extends StatelessWidget {
  const _EntriesPanel({
    required this.scheme,
    required this.children,
  });

  final ColorScheme scheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: S1Surface.nestedPanelItem(scheme),
          borderRadius: S1Shape.small,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalScore,
    required this.participantCount,
    required this.accentColor,
    required this.expanded,
    required this.hiddenCount,
  });

  final int totalScore;
  final int participantCount;
  final Color accentColor;
  final bool expanded;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sign = totalScore >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: S1Shape.extraSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '评分 $sign$totalScore',
            style: textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($participantCount人)',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (expanded || hiddenCount > 0) ...[
            Text(
              expanded ? '收起' : '查看其余$hiddenCount条',
              style: textTheme.labelSmall?.copyWith(
                color: expanded ? scheme.onSurfaceVariant : scheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: !expanded && hiddenCount > 0
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.accentColor});

  final RateLog entry;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sign = entry.score >= 0 ? '+' : '';
    final uid = entry.uid;
    final ratedAt = entry.ratedAt;
    final ratedAtText = ratedAt == null
        ? ''
        : formatDateTime(ratedAt.millisecondsSinceEpoch ~/ 1000);
    final username = Text(
      entry.username,
      style: textTheme.bodySmall?.copyWith(
        color: uid == null ? scheme.onSurface : scheme.primary,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                uid == null
                    ? username
                    : Semantics(
                        button: true,
                        label: '查看 ${entry.username} 的资料',
                        child: S1ClickRegion(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showUserProfileSheet(
                            context,
                            future: ref.read(userProfileProvider(uid).future),
                          ),
                          child: username,
                        ),
                      ),
                if (ratedAtText.isNotEmpty)
                  Text(
                    ratedAtText,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$sign${entry.score}',
              textAlign: TextAlign.center,
              style: textTheme.labelMedium?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              entry.reason.isEmpty ? '-' : entry.reason,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
