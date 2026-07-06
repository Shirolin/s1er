import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/thread_list_provider.dart';
import '../services/api_service.dart';
import '../widgets/thread_card.dart';

class ForumListScreen extends ConsumerWidget {
  final String fid;

  const ForumListScreen({super.key, required this.fid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(threadListProvider(fid));

    return Scaffold(
      appBar: AppBar(title: const Text('Forum')),
      body: threadsAsync.when(
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
                  onPressed: () => ref.invalidate(threadListProvider(fid)),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
        data: (threads) => RefreshIndicator(
          onRefresh: () => ref.read(threadListProvider(fid).notifier).refresh(),
          child: ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, index) => ThreadCard(thread: threads[index]),
          ),
        ),
      ),
    );
  }
}
