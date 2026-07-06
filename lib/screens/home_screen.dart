import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/forum_list_provider.dart';
import '../models/forum_category.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage1st'),
        actions: [
          if (!isLoggedIn)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Login'),
            ),
        ],
      ),
      body: !isLoggedIn && _currentTab < 3
          ? _LoginPrompt()
          : _currentTab == 0
              ? _ForumTab()
              : _currentTab == 1
                  ? const Center(child: Text('Search'))
                  : _currentTab == 2
                      ? const Center(child: Text('Messages'))
                      : const ProfileScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum), label: 'Forum'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}

class _ForumTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forumsAsync = ref.watch(forumListProvider);

    return forumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (e.toString().contains('请先登录')) ...[
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
                Text('加载失败: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(forumListProvider),
                  child: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
      data: (categories) => RefreshIndicator(
        onRefresh: () => ref.read(forumListProvider.notifier).refresh(),
        child: ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) =>
              _ForumCategoryTile(category: categories[index]),
        ),
      ),
    );
  }
}

class _ForumCategoryTile extends StatelessWidget {
  final ForumCategory category;

  const _ForumCategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              category.name,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          if (category.subforums.isNotEmpty)
            ...category.subforums.map((sub) => _ForumTile(forum: sub))
          else
            _ForumTile(forum: category),
        ],
      ),
    );
  }
}

class _ForumTile extends StatelessWidget {
  final ForumCategory forum;

  const _ForumTile({required this.forum});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.forum_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: Text(forum.name),
      subtitle: forum.description.isNotEmpty
          ? Text(forum.description,
              maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Text(
        '${forum.threads}帖',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      onTap: () => context.push('/forum/${forum.fid}'),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              '登录后即可浏览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'S1 论坛需要登录才能查看内容',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login),
              label: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}
