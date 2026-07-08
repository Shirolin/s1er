import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/thread.dart';

class ThreadCard extends StatelessWidget {

  const ThreadCard({super.key, required this.thread});
  final Thread thread;

  String _formatTime(int dateline) {
    if (dateline <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateline * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    if (dt.year == now.year) return '$month-$day';
    return '${dt.year}-$month-$day';
  }

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
    final timeStr = _formatTime(thread.dateline);
    final scheme = Theme.of(context).colorScheme;
    final hasTag = thread.typeName != null && thread.typeName!.isNotEmpty;
    final isSticky = thread.isSticky;
    final totalPages = _calcTotalPages(thread.replies);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: InkWell(
        onTap: () => context.push('/thread/${thread.tid}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSticky) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.push_pin, size: 14, color: scheme.primary),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (hasTag) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _ThreadTag(
                        label: thread.typeName!.replaceAll('[', '').replaceAll(']', ''),
                        color: scheme.secondary,
                        bgColor: scheme.secondaryContainer.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      thread.subject,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        height: 1.4,
                        fontWeight: isSticky ? FontWeight.bold : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    thread.author,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 11, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      timeStr,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.visibility_outlined, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    '${thread.views}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chat_bubble_outline, size: 12, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    '${thread.replies}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                  if (totalPages > 1) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showPageSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined, size: 11, color: scheme.onTertiaryContainer),
                            const SizedBox(width: 2),
                            Text(
                              '$totalPages页',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadTag extends StatelessWidget {
  const _ThreadTag({required this.label, required this.color, required this.bgColor});
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

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
                        Text(
                          '选择页码',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '共 $totalPages 页',
                    style: TextStyle(
                      fontSize: 12,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '第 $startPost - $endPost 楼',
                            style: TextStyle(
                              fontSize: 13,
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
