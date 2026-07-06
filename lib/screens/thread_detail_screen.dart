import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/post_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/post_item.dart';

class ThreadDetailScreen extends ConsumerWidget {
  final String tid;

  const ThreadDetailScreen({super.key, required this.tid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postProvider(tid));
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: postsAsync.whenOrNull(
              data: (s) => s.threadSubject != null
                  ? Text(s.threadSubject!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
            ) ??
            const Text('Thread'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(postProvider(tid).notifier).refresh(),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (e is LoginRequiredException) ...[
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('请先登录', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('去登录'),
                  ),
                ] else ...[
                  Text('Error: $e'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(postProvider(tid).notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
        data: (state) => Column(
          children: [
            Expanded(
              child: state.posts.isEmpty
                  ? const Center(child: Text('No posts'))
                  : ListView.builder(
                      itemCount: state.posts.length,
                      itemBuilder: (context, index) =>
                          PostItem(post: state.posts[index]),
                    ),
            ),
            _PostPaginationBar(tid: tid, state: state),
          ],
        ),
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              onPressed: () => context.push('/compose?tid=$tid'),
              child: const Icon(Icons.reply),
            )
          : null,
    );
  }
}

class _PostPaginationBar extends ConsumerWidget {
  final String tid;
  final PostListState state;

  const _PostPaginationBar({required this.tid, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(postProvider(tid).notifier);
    final page = state.currentPage;
    final total = state.totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: page > 1 ? () => notifier.goToPage(1) : null,
            tooltip: '首页',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 1 ? () => notifier.goToPage(page - 1) : null,
            tooltip: '上一页',
          ),
          GestureDetector(
            onTap: () => _showPageJumpDialog(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$page / $total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                page < total ? () => notifier.goToPage(page + 1) : null,
            tooltip: '下一页',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed:
                page < total ? () => notifier.goToPage(total) : null,
            tooltip: '末页',
          ),
        ],
      ),
    );
  }

  void _showPageJumpDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳转到页码'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 - ${state.totalPages}',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null &&
                  page >= 1 &&
                  page <= state.totalPages) {
                ref.read(postProvider(tid).notifier).goToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
