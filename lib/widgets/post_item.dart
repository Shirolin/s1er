import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../providers/post_provider.dart';
import '../utils/format_utils.dart';
import 'bbcode_renderer.dart';
import 'web_avatar.dart';

class PostItem extends ConsumerWidget {
  const PostItem({super.key, required this.post, this.displayFloor, this.tid});
  final Post post;
  final int? displayFloor;
  final String? tid;

  void _showUserInfo(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final future = ref.read(apiServiceProvider).getUserProfileByUid(post.authorId);

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<User?>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final user = snapshot.data;
            if (user == null) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('加载失败'),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 头部：头像 + 用户名 + 关闭按钮
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 8, 20),
                    color: scheme.surfaceContainerLow,
                    child: Row(
                      children: [
                        WebAvatar(
                          url: user.avatar,
                          radius: 36,
                          fallbackLetter: user.username.isNotEmpty ? user.username[0] : '?',
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.username, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(user.groupTitle ?? '用户', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // 数据区
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        _InfoItem(label: '积分', value: user.credits.toString()),
                        _InfoItem(label: '战斗力', value: user.combat.toString()),
                        _InfoItem(label: '鹅球', value: user.deadfish.toString()),
                        _InfoItem(label: '帖子', value: user.posts.toString()),
                        _InfoItem(label: '注册时间', value: user.regdate),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStr = formatDateTime(post.dateline);
    final floor = displayFloor ?? post.floor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showUserInfo(context, ref),
                  child: WebAvatar(
                    url: post.avatar,
                    radius: 16,
                    fallbackLetter: post.author.isNotEmpty ? post.author[0] : '?',
                  ),
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
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // TODO: Implement actions
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'author', child: Text('只看该作者')),
                    const PopupMenuItem(value: 'reply', child: Text('回复')),
                    const PopupMenuItem(value: 'rate', child: Text('评分')),
                    const PopupMenuItem(value: 'report', child: Text('举报')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#$floor',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            BbcodeRenderer(bbcode: post.message, currentTid: tid),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


