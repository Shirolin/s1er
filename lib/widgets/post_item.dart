import 'package:flutter/material.dart';
import '../models/post.dart';
import 'bbcode_renderer.dart';

class PostItem extends StatelessWidget {

  const PostItem({super.key, required this.post});
  final Post post;

  String _formatTime(int dateline) {
    if (dateline <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateline * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeStr = _formatTime(post.dateline);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(post.author.isNotEmpty ? post.author[0] : '?'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),),
                      if (timeStr.isNotEmpty)
                        Text(timeStr,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),),
                    ],
                  ),
                ),
                Text('#${post.floor}',
                    style: TextStyle(color: scheme.onSurfaceVariant),),
              ],
            ),
            const Divider(),
            BbcodeRenderer(bbcode: post.message),
          ],
        ),
      ),
    );
  }
}
