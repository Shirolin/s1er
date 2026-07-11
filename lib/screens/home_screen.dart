import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/forum_list_provider.dart';
import '../providers/pm_list_provider.dart';
import '../providers/notice_list_provider.dart';
import '../providers/messages_segment_provider.dart';
import '../providers/settings_provider.dart';
import '../models/forum_category.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/s1_error_view.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

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

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (!wasLoggedIn && next.isLoggedIn) {
        // 游客「我的」(index 1) 登录后会误落到「搜索」，强制回到论坛并刷新列表
        setState(() => _currentTab = 0);
        ref.invalidate(forumListProvider);
      } else if (wasLoggedIn && !next.isLoggedIn && _currentTab > 1) {
        setState(() => _currentTab = 0);
        ref.invalidate(forumListProvider);
      }
    });

    // 游客只有 2 个 Tab，越界时用计算值，避免在 build 中改写 state
    final tabIndex = (!isLoggedIn && _currentTab > 1) ? 0 : _currentTab;

    final isProfileTab = isLoggedIn ? tabIndex == 3 : tabIndex == 1;
    final isMessagesTab = isLoggedIn && tabIndex == 2;
    final messagesSegment =
        isMessagesTab ? ref.watch(messagesSegmentProvider) : 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          isProfileTab
              ? '个人资料'
              : isMessagesTab
                  ? '消息'
                  : 'Stage1st',
        ),
        actions: isProfileTab
            ? [
                if (isLoggedIn)
                  AppBarMoreMenu(
                    onRefresh: () =>
                        ref.read(authStateProvider.notifier).refreshProfile(),
                    browserUrl: '${ApiConfig.baseUrl}/home.php?mod=space',
                  ),
              ]
            : isMessagesTab
                ? [
                    AppBarMoreMenu(
                      onRefresh: () {
                        ref.read(pmListProvider.notifier).refresh();
                        ref.read(noticeListProvider.notifier).refresh();
                      },
                      browserUrl: messagesBrowserUrl(messagesSegment),
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
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FilledButton.tonal(
                      onPressed: () => context.push('/login'),
                      child: const Text('登录'),
                    ),
                  ),
              ],
      ),
      body: isLoggedIn
          ? tabIndex == 0
              ? const _ForumTab()
              : tabIndex == 1
                  ? const Center(child: Text('搜索'))
                  : tabIndex == 2
                      ? const MessagesScreen()
                      : const ProfileBody()
          : tabIndex == 0
              ? const _ForumTab()
              : const ProfileBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (index) {
          if (_currentTab == 2 && index != 2) {
            ref.read(messagesSegmentProvider.notifier).state = 0;
          }
          setState(() => _currentTab = index);
        },
        destinations: isLoggedIn
            ? const [
                NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
                NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
                NavigationDestination(icon: Icon(Icons.message), label: '消息'),
                NavigationDestination(icon: Icon(Icons.person), label: '我的'),
              ]
            : const [
                NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
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
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.forum_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    '暂无版块数据',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请下拉刷新或稍后重试',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scrollbar(
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
        );
      },
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
            child: Semantics(
              button: hasSubs,
              expanded: hasSubs ? !isCollapsed : null,
              label: category.name,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
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


