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
        title: const Text('Thread'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(postProvider(tid)),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
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
                  onPressed: () => ref.invalidate(postProvider(tid)),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
        data: (posts) => posts.isEmpty
            ? const Center(child: Text('No posts'))
            : ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) =>
                    PostItem(post: posts[index]),
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
