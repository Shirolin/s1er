import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/forum_list_provider.dart';
import '../providers/settings_provider.dart';
import '../models/forum_category.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/s1_error_view.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
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
        elevation: 0,
        title: Text(_currentTab == 3 ? '个人资料' : 'Stage1st'),
        actions: _currentTab == 3
            ? [
                if (isLoggedIn)
                  AppBarMoreMenu(
                    onRefresh: () =>
                        ref.read(authStateProvider.notifier).refreshProfile(),
                    browserUrl: '${ApiConfig.baseUrl}/home.php?mod=space',
                  ),
              ]
            : [
                if (isLoggedIn)
                  AppBarMoreMenu(
                    onRefresh: () =>
                        ref.read(forumListProvider.notifier).refresh(),
                    browserUrl: ApiConfig.baseUrl,
                  )
                else
                  FilledButton.tonal(
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
                      : const ProfileBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.message), label: '消息'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
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
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () => ref.read(forumListProvider.notifier).refresh(),
        onLogin: () => context.push('/login'),
      ),
      data: (categories) => Scrollbar(
        child: RefreshIndicator(
          onRefresh: () => ref.read(forumListProvider.notifier).refresh(),
          child: ListView.builder(
            primary: true,
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
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: scheme.surfaceContainer,
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
                    label: formatCount(category.threads),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    label: formatCount(category.posts),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(label, style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
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
    final textTheme = Theme.of(context).textTheme;
    final hasDesc = forum.description.isNotEmpty;

    return InkWell(
      onTap: () => context.push('/forum/${forum.fid}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 版块图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: S1Shape.small,
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
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasDesc) ...[
                    const SizedBox(height: 2),
                    Text(
                      forum.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            // 今日新帖数 / 帖子数
            if (forum.todayPosts > 0)
              Badge(
                label: CompactLabel.text(
                  '${forum.todayPosts}',
                  style: CompactLabel.style(
                    context,
                    color: scheme.onPrimary,
                  ),
                ),
                backgroundColor: scheme.primary,
              )
            else
              Text(
                formatCount(forum.threads),
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
