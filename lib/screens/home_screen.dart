import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/forum_list_provider.dart';
import '../providers/settings_provider.dart';
import '../models/forum_category.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';

String _formatCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}千';
  return '$n';
}

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
              ? const _ForumTab()
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
  const _ForumTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forumsAsync = ref.watch(forumListProvider);

    return forumsAsync.when(
      loading: () => const Column(
        children: [
          LinearProgressIndicator(),
          Expanded(child: SizedBox()),
        ],
      ),
      error: (e, st) => _ForumErrorView(error: e),
      data: (categories) => Scrollbar(
        child: RefreshIndicator(
          onRefresh: () => ref.read(forumListProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) =>
                _ForumCategoryTile(category: categories[index]),
          ),
        ),
      ),
    );
  }
}

class _ForumErrorView extends ConsumerWidget {

  const _ForumErrorView({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = error is LoginRequiredException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLogin ? Icons.lock_outline : Icons.error_outline,
              size: 56,
              color: isLogin ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isLogin ? '请先登录' : '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!isLogin) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                if (isLogin) {
                  context.push('/login');
                } else {
                  ref.read(forumListProvider.notifier).refresh();
                }
              },
              icon: Icon(isLogin ? Icons.login : Icons.refresh),
              label: Text(isLogin ? '去登录' : '重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForumCategoryTile extends ConsumerWidget {

  const _ForumCategoryTile({required this.category});
  final ForumCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasSubs = category.subforums.isNotEmpty;
    final isCollapsed = ref.watch(
      settingsProvider.select((s) => s.collapsedForums.contains(category.fid)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类头部
          InkWell(
            onTap: hasSubs
                ? () => ref
                    .read(settingsProvider.notifier)
                    .toggleForumCollapse(category.fid)
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _StatChip(
                    icon: Icons.article_outlined,
                    label: _formatCount(category.threads),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    label: _formatCount(category.posts),
                  ),
                  if (hasSubs) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 子版块列表
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            child: (hasSubs && !isCollapsed)
                ? Column(
                    children: category.subforums
                        .map((sub) => _ForumTile(forum: sub))
                        .toList(),
                  )
                : const SizedBox.shrink(),
          ),
          if (!hasSubs) _ForumTile(forum: category),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {

  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ForumTile extends StatelessWidget {

  const _ForumTile({required this.forum});
  final ForumCategory forum;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDesc = forum.description.isNotEmpty;

    return InkWell(
      onTap: () => context.push('/forum/${forum.fid}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 版块图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 20,
                color: scheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            // 版块信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    forum.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasDesc) ...[
                    const SizedBox(height: 2),
                    Text(
                      forum.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            // 帖子数
            Text(
              _formatCount(forum.threads),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
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
                size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant,),
            const SizedBox(height: 20),
            Text(
              '登录后即可浏览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'S1 论坛需要登录才能查看内容',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
