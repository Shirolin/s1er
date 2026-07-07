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

  int _calcTotalPages(int replies, {int perPage = 30}) {
    final totalPosts = replies + 1;
    return (totalPosts / perPage).ceil().clamp(1, 9999);
  }

  void _showThreadPageJump(BuildContext context) {
    final totalPages = _calcTotalPages(thread.replies);
    if (totalPages <= 1) {
      context.push('/thread/${thread.tid}');
      return;
    }

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('跳转到帖子页面', style: Theme.of(context).textTheme.titleSmall),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 - $totalPages',
            isDense: true,
          ),
          autofocus: true,
          onSubmitted: (_) => _performThreadJump(ctx, controller, totalPages),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/thread/${thread.tid}');
            },
            child: const Text('首页'),
          ),
          FilledButton(
            onPressed: () => _performThreadJump(context, controller, totalPages),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  void _performThreadJump(BuildContext context, TextEditingController controller, int totalPages) {
    final page = int.tryParse(controller.text);
    if (page != null && page >= 1 && page <= totalPages) {
      Navigator.pop(context);
      GoRouter.of(context).push('/thread/${thread.tid}?page=$page');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(thread.dateline);
    final scheme = Theme.of(context).colorScheme;
    final hasTag = thread.typeName != null && thread.typeName!.isNotEmpty;
    final isSticky = thread.isSticky;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: InkWell(
        onTap: () => context.push('/thread/${thread.tid}'),
        onLongPress: () => _showThreadPageJump(context),
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
                  const SizedBox(width: 12),
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
                  const Spacer(),
                  if (timeStr.isNotEmpty) ...[
                    Icon(Icons.access_time, size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      timeStr,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
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
