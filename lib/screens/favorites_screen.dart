import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../models/favorite_item.dart';
import '../models/thread_destination.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_forum_pins_provider.dart';
import '../providers/favorite_list_provider.dart';
import '../providers/favorite_membership_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/favorite_confirm_dialog.dart';
import '../utils/format_utils.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/thread_navigation.dart';
import '../theme/s1_haptics.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_list_boundary_footer.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/s1_desktop_scaffold.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key, this.initialSegment});

  /// Optional `all` / `thread` / `forum` (from `/favorites?segment=`).
  final String? initialSegment;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Set<int> _visitedTabs;
  bool _membershipEnsured = false;
  final _swipeKeys = List.generate(
    3,
    (_) => GlobalKey<S1SwipePaginationState>(),
  );

  static const _segments = [
    FavoriteSegment.all,
    FavoriteSegment.thread,
    FavoriteSegment.forum,
  ];

  static int _indexForSegment(String? segment) {
    switch (segment) {
      case 'thread':
        return 1;
      case 'forum':
        return 2;
      case 'all':
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _indexForSegment(widget.initialSegment);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _visitedTabs = {_tabController.index};
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    _visitedTabs.add(index);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _ensureMembershipSynced() {
    if (_membershipEnsured) return;
    _membershipEnsured = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(favoriteMembershipProvider.notifier).ensureSynced();
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureMembershipSynced();
    final uid = ref.watch(
      authStateProvider.select((auth) => auth.user?.uid),
    );
    final activeSegment = _segments[_tabController.index];
    final activePage = ref
            .watch(favoriteListProvider(activeSegment))
            .asData
            ?.value
            .currentPage ??
        1;
    final browserUrl = ApiConfig.favoriteBrowserUrl(
      uid: uid,
      type: activeSegment.apiType,
      page: activePage,
    );

    return S1DesktopScaffold(
      highlightedTab: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('我的收藏'),
          actions: [
            AppBarMoreMenu(
              onRefresh: () {
                final segment = _segments[_tabController.index];
                ref.read(favoriteListProvider(segment).notifier).refresh();
                ref.read(favoriteMembershipProvider.notifier).ensureSynced();
              },
              browserUrl: browserUrl,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '全部'),
              Tab(text: '帖子'),
              Tab(text: '板块'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < _segments.length; i++)
              _visitedTabs.contains(i)
                  ? _FavoriteListBody(
                      segment: _segments[i],
                      swipeKey: _swipeKeys[i],
                    )
                  : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _FavoriteListBody extends ConsumerWidget {
  const _FavoriteListBody({
    required this.segment,
    required this.swipeKey,
  });

  final FavoriteSegment segment;
  final GlobalKey<S1SwipePaginationState> swipeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoriteListProvider(segment));

    return async.when(
      loading: () => const Column(
        children: [
          LinearProgressIndicator(),
          Expanded(child: SizedBox()),
        ],
      ),
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () => S1Haptics.wrapRefresh(
          () => ref.read(favoriteListProvider(segment).notifier).refresh(),
        ),
        onLogin: () => context.push('/login'),
      ),
      data: (state) => Column(
        children: [
          Expanded(
            child: S1SwipePagination(
              key: swipeKey,
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (page) => ref
                  .read(favoriteListProvider(segment).notifier)
                  .goToPage(page),
              pageBuilder: (context, scrollController) => RefreshIndicator(
                onRefresh: () => S1Haptics.wrapRefresh(() async {
                  await ref
                      .read(favoriteListProvider(segment).notifier)
                      .refresh();
                  await ref
                      .read(favoriteMembershipProvider.notifier)
                      .ensureSynced();
                }),
                child: state.items.isEmpty
                    ? ListView(
                        controller: scrollController,
                        children: const [
                          SizedBox(height: 48),
                          Center(child: Text('暂无收藏')),
                        ],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index >= state.items.length) {
                            return S1ListBoundaryFooter(
                              kind: pagedBoundaryKind(
                                currentPage: state.currentPage,
                                totalPages: state.totalPages,
                              ),
                            );
                          }
                          final item = state.items[index];
                          return KeyedSubtree(
                            key: ValueKey('favorite_${item.favid}'),
                            child: _FavoriteTile(
                              item: item,
                              onRemove: () =>
                                  _removeFavorite(context, ref, item),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          if (state.totalPages > 1)
            PaginationBar(
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (page) => ref
                  .read(favoriteListProvider(segment).notifier)
                  .goToPage(page),
            ),
        ],
      ),
    );
  }

  Future<void> _removeFavorite(
    BuildContext context,
    WidgetRef ref,
    FavoriteItem item,
  ) async {
    final confirmed = await confirmUnfavorite(context);
    if (!confirmed || !context.mounted) return;

    final ok =
        await ref.read(favoriteListProvider(segment).notifier).removeItem(item);
    if (!context.mounted) return;
    if (ok) {
      ref.read(favoriteMembershipProvider.notifier).untrack(item);
      if (item.type == FavoriteType.forum) {
        ref.invalidate(favoriteForumPinsProvider);
      }
      S1SnackBar.show(context, message: '已取消收藏');
    } else {
      S1SnackBar.show(context, message: '取消收藏失败');
    }
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({
    required this.item,
    required this.onRemove,
  });

  final FavoriteItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.type == FavoriteType.forum) {
      final isHidden = ref.watch(
        settingsProvider.select((s) => s.hiddenForums.contains(item.id)),
      );
      return _FavoriteForumTile(
        item: item,
        onRemove: onRemove,
        isHidden: isHidden,
      );
    }
    return _FavoriteThreadTile(item: item, onRemove: onRemove);
  }
}

class _FavoriteThreadTile extends StatelessWidget {
  const _FavoriteThreadTile({
    required this.item,
    required this.onRemove,
  });

  final FavoriteItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => context.push(
          ThreadRouteCodec.encodePath(ResumeThread(item.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (item.forumName != null &&
                            item.forumName!.isNotEmpty)
                          item.forumName,
                        if (item.dateline > 0) formatTimeAgo(item.dateline),
                        if (item.views != null) '${item.views} 浏览',
                        if (item.replies != null) '${item.replies} 回复',
                      ].whereType<String>().join(' · '),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '取消收藏',
                icon: const Icon(Icons.bookmark_remove_outlined),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteForumTile extends StatelessWidget {
  const _FavoriteForumTile({
    required this.item,
    required this.onRemove,
    this.isHidden = false,
  });

  final FavoriteItem item;
  final VoidCallback onRemove;
  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/forum/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isHidden || item.dateline > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (isHidden) '已屏蔽',
                          if (item.dateline > 0) formatTimeAgo(item.dateline),
                        ].join(' · '),
                        style: textTheme.labelSmall?.copyWith(
                          color:
                              isHidden ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '取消收藏',
                icon: const Icon(Icons.bookmark_remove_outlined),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
