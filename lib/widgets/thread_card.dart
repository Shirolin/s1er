import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/thread.dart';

class ThreadCard extends StatelessWidget {

  const ThreadCard({super.key, required this.thread});
  final Thread thread;

  String _formatTime(int dateline) {
    if (dateline <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateline * 1000);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(thread.dateline);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/thread/${thread.tid}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thread.subject,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(thread.author,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),),
                  const Spacer(),
                  if (timeStr.isNotEmpty) ...[
                    Icon(Icons.access_time, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(timeStr,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${thread.views}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),),
                  const SizedBox(width: 16),
                  Icon(Icons.comment_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${thread.replies}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
