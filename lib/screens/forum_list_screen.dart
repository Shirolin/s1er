import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/thread_list_provider.dart';
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
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(threadListProvider(fid)),
                child: const Text('Retry'),
              ),
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
