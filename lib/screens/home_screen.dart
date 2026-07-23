import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_forum_pins_provider.dart';
import '../providers/favorite_membership_provider.dart';
import '../providers/forum_list_provider.dart';
import '../providers/pm_list_provider.dart';
import '../providers/notice_list_provider.dart';
import '../providers/messages_segment_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/unread_count_provider.dart';
import '../models/favorite_item.dart';
import '../models/forum_category.dart';
import '../models/notice_item.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/forum_index_view.dart';
import '../utils/s1_snack_bar.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/favorite_confirm_dialog.dart';
import '../widgets/hide_forum_confirm_dialog.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_content_width.dart';
import '../widgets/s1_desktop_scaffold.dart';
import '../widgets/s1_menu.dart';
import '../utils/compact_label.dart';
import '../utils/format_utils.dart';
import '../utils/window_size.dart';
import 'messages_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return const _HomeScreenBody();
    }
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    final highlightedTab = switch ((isLoggedIn, tab)) {
      (true, 'search') => 1,
      (true, 'messages') => 2,
      (true, 'profile') => 3,
      (false, 'profile') => 1,
      _ => 0,
    };
    return S1DesktopScaffold(
      highlightedTab: highlightedTab,
      child: const _HomeScreenBody(),
    );
  }
}

class _HomeScreenBody extends ConsumerStatefulWidget {
  const _HomeScreenBody();

  @override
  ConsumerState<_HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends ConsumerState<_HomeScreenBody> {
  int _fallbackTab = 0;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );

    final router = GoRouter.maybeOf(context);
    final requestedTab = router == null
        ? null
        : GoRouterState.of(context).uri.queryParameters['tab'];
    final tabIndex = switch ((isLoggedIn, requestedTab)) {
      (true, 'search') => 1,
      (true, 'messages') => 2,
      (true, 'profile') => 3,
      (false, 'profile') => 1,
      _ => 0,
    };
    final selectedTab = router == null
        ? (isLoggedIn ? _fallbackTab.clamp(0, 3) : (_fallbackTab > 0 ? 1 : 0))
        : tabIndex;

    final isProfileTab = isLoggedIn ? selectedTab == 3 : selectedTab == 1;
    final isMessagesTab = isLoggedIn && selectedTab == 2;
    final messagesSegment =
        isMessagesTab ? ref.watch(messagesSegmentProvider) : 0;
    final noticeFeed = isMessagesTab
        ? ref.watch(noticeFeedSelectionProvider)
        : NoticeFeed.mypost;
    final messagesPage = !isMessagesTab
        ? 1
        : messagesSegment == 0
            ? ref.watch(
                noticeListProvider.select((async) {
                  final state = async.asData?.value;
                  return state?.feed == noticeFeed ? state!.currentPage : 1;
                }),
              )
            : ref.watch(
                pmListProvider.select(
                  (async) => async.asData?.value.currentPage ?? 1,
                ),
              );

    final unreadTotal =
        isLoggedIn ? ref.watch(unreadCountProvider.select((c) => c.total)) : 0;
    final unreadDisplay = isLoggedIn
        ? ref.watch(unreadCountProvider.select((c) => c.displayBadge))
        : '';

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
                      browserUrl: messagesBrowserUrl(
                        messagesSegment,
                        noticeFeed: noticeFeed,
                        page: messagesPage,
                      ),
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
      body: S1ContentWidth(
        child: isLoggedIn
            ? selectedTab == 0
                ? const _ForumTab()
                : selectedTab == 1
                    ? const SearchScreen()
                    : selectedTab == 2
                        ? const MessagesScreen()
                        : const ProfileBody(
                            key: ValueKey('profile-logged-in'),
                          )
            : selectedTab == 0
                ? const _ForumTab()
                : const ProfileBody(key: ValueKey('profile-guest')),
      ),
      bottomNavigationBar: router != null && context.isMediumOrAbove
          ? null
          : NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: (index) {
                S1Haptics.selection();
                if (selectedTab == 2 && index != 2) {
                  ref.read(messagesSegmentProvider.notifier).select(0);
                }
                if (router == null) {
                  setState(() => _fallbackTab = index);
                  return;
                }
                final tab = isLoggedIn
                    ? const ['forum', 'search', 'messages', 'profile'][index]
                    : const ['forum', 'profile'][index];
                context.go(tab == 'forum' ? '/' : '/?tab=$tab');
              },
              destinations: isLoggedIn
                  ? [
                      const NavigationDestination(
                        icon: Icon(Icons.forum),
                        label: '论坛',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.search),
                        label: '搜索',
                      ),
                      NavigationDestination(
                        icon: Badge(
                          label: Text(unreadDisplay),
                          isLabelVisible: unreadTotal > 0,
                          child: const Icon(Icons.message),
                        ),
                        label: '消息',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.person),
                        label: '我的',
                      ),
                    ]
                  : const [
                      NavigationDestination(
                        icon: Icon(Icons.forum),
                        label: '论坛',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person),
                        label: '我的',
                      ),
                    ],
            ),
    );
  }
}

class _ForumTab extends ConsumerStatefulWidget {
  const _ForumTab();

  @override
  ConsumerState<_ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends ConsumerState<_ForumTab> {
  bool _membershipEnsured = false;

  void _ensureMembershipSynced() {
    if (_membershipEnsured) return;
    if (!ref.read(authStateProvider).isLoggedIn) return;
    _membershipEnsured = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(favoriteMembershipProvider.notifier).ensureSynced();
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureMembershipSynced();
    final forumsAsync = ref.watch(forumListProvider);
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    if (!isLoggedIn) {
      _membershipEnsured = false;
    }
    final hiddenForums = ref.watch(
      settingsProvider.select((s) => s.hiddenForums),
    );
    final pinItems =
        ref.watch(favoriteForumPinsProvider).asData?.value ?? const [];

    return forumsAsync.when(
      loading: () => const Column(
        children: [
          LinearProgressIndicator(),
          Expanded(child: SizedBox()),
        ],
      ),
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () => S1Haptics.wrapRefresh(
          () => ref.read(forumListProvider.notifier).refresh(),
        ),
        onLogin: () => context.push('/login'),
      ),
      data: (categories) {
        Future<void> refresh() => S1Haptics.wrapRefresh(() async {
              await ref.read(forumListProvider.notifier).refresh();
              if (isLoggedIn) {
                await ref.read(favoriteForumPinsProvider.notifier).refresh();
              }
            });

        final pinTitles = {
          for (final item in pinItems) item.id: item.title,
        };
        final view = buildForumIndexView(
          categories: categories,
          favoriteFidsOrdered: [
            for (final item in pinItems) item.id,
          ],
          favoriteTitleFor: (fid) => pinTitles[fid] ?? fid,
          hiddenForums: hiddenForums,
        );

        if (categories.isEmpty) {
          final scheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          return RefreshIndicator(
            onRefresh: refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无版块数据',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '请点击重试或下拉刷新',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }
        return Scrollbar(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: context.isLargeOrAbove
                ? _ForumCategoryGrid(view: view)
                : ListView(
                    primary: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (view.pinned.isNotEmpty)
                        _FavoriteForumsSection(forums: view.pinned),
                      for (final category in view.categories)
                        _ForumCategoryTile(category: category),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _FavoriteForumsSection extends StatelessWidget {
  const _FavoriteForumsSection({
    required this.forums,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<ForumCategory> forums;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已收藏',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/favorites?segment=forum'),
                  child: const Text('管理'),
                ),
              ],
            ),
          ),
          for (final forum in forums)
            _ForumTile(forum: forum, compact: true),
        ],
      ),
    );
  }
}

class _ForumCategoryGrid extends StatelessWidget {
  const _ForumCategoryGrid({required this.view});

  final ForumIndexView view;

  @override
  Widget build(BuildContext context) {
    final categories = view.categories;
    if (categories.isEmpty && view.pinned.isEmpty) {
      return ListView(primary: true, children: const []);
    }

    if (categories.length <= 1) {
      return ListView(
        primary: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (view.pinned.isNotEmpty)
            _FavoriteForumsSection(forums: view.pinned),
          if (categories.length == 1)
            _ForumCategoryTile(category: categories.single),
        ],
      );
    }

    final leftCategories = <ForumCategory>[];
    final rightCategories = <ForumCategory>[];
    for (var index = 0; index < categories.length; index++) {
      (index.isEven ? leftCategories : rightCategories).add(categories[index]);
    }

    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (view.pinned.isNotEmpty)
          _FavoriteForumsSection(
            forums: view.pinned,
            margin: const EdgeInsets.only(bottom: 16),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final category in leftCategories)
                    _ForumCategoryTile(
                      category: category,
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  for (final category in rightCategories)
                    _ForumCategoryTile(
                      category: category,
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ForumCategoryTile extends ConsumerWidget {
  const _ForumCategoryTile({
    required this.category,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final ForumCategory category;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasSubs = category.subforums.isNotEmpty;
    final isCollapsed = ref.watch(
      settingsProvider.select((s) => s.collapsedForums.contains(category.fid)),
    );

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类头部：与卡身同色（不涂 page tint，避免「挖洞」）；层级靠字色/图标。
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
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
          // 子版块列表（无描边分隔；层级靠间距）
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            child: (hasSubs && !isCollapsed)
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: category.subforums.length,
                    itemBuilder: (context, index) =>
                        _ForumTile(forum: category.subforums[index]),
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
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ForumTile extends ConsumerWidget {
  const _ForumTile({
    required this.forum,
    this.compact = false,
  });

  final ForumCategory forum;
  final bool compact;

  Future<void> _hide(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmHideForum(context);
    if (!confirmed || !context.mounted) return;
    ref.read(settingsProvider.notifier).hideForum(forum.fid);
    S1SnackBar.show(context, message: '已屏蔽此版块');
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
    if (!isLoggedIn) {
      if (context.mounted) {
        S1SnackBar.show(context, message: '请先登录');
      }
      return;
    }

    final membership = ref.read(favoriteMembershipProvider);
    final wasFavorited =
        membership.isFavorited(FavoriteType.forum, forum.fid);
    if (wasFavorited) {
      final confirmed = await confirmUnfavorite(context);
      if (!confirmed || !context.mounted) return;
    }

    final error = await ref
        .read(favoriteMembershipProvider.notifier)
        .toggleForum(forum.fid);
    if (!context.mounted) return;
    if (error != null) {
      S1SnackBar.error(context, message: error);
      return;
    }
    S1SnackBar.show(
      context,
      message: wasFavorited ? '已取消收藏' : '已收藏',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasDesc = !compact && forum.description.isNotEmpty;
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final isFavorited = isLoggedIn &&
        ref.watch(
          favoriteMembershipProvider.select(
            (s) => s.isFavorited(FavoriteType.forum, forum.fid),
          ),
        );

    return MenuAnchor(
      menuChildren: [
        if (isLoggedIn)
          s1MenuItem(
            onPressed: () => _toggleFavorite(context, ref),
            icon: isFavorited
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
            label: isFavorited ? '取消收藏' : '收藏此版块',
            destructive: isFavorited,
          ),
        s1MenuItem(
          onPressed: () => _hide(context, ref),
          icon: Icons.visibility_off_outlined,
          label: '屏蔽此版块',
          destructive: true,
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () => context.push('/forum/${forum.fid}'),
          onLongPress: () {
            S1Haptics.selection();
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 10 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 32 : 36,
                  height: compact ? 32 : 36,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: S1Shape.small,
                  ),
                  child: Icon(
                    Icons.forum_outlined,
                    size: compact ? 18 : 20,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              forum.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFavorited) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star,
                              size: 14,
                              color: scheme.tertiary,
                            ),
                          ],
                        ],
                      ),
                      if (hasDesc) ...[
                        const SizedBox(height: 2),
                        Text(
                          forum.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
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
                else if (!compact)
                  Text(
                    formatCount(forum.threads),
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
