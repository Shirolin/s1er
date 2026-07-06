import 'package:flutter/material.dart';
import '../models/post.dart';
import 'bbcode_renderer.dart';

class PostItem extends StatelessWidget {
  final Post post;

  const PostItem({super.key, required this.post});

  String _formatTime(int dateline) {
    if (dateline <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateline * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (timeStr.isNotEmpty)
                        Text(timeStr,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text('#${post.floor}',
                    style: TextStyle(color: Colors.grey[600])),
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
