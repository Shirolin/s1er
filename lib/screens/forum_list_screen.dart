import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../widgets/s1_desktop_scaffold.dart';
import '../widgets/s1_content_width.dart';
import 'thread_detail_screen.dart';
import '../providers/forum_name_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_list_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/favorite_bookmark_button.dart';
import '../widgets/forum_split_breadcrumb_title.dart';
import '../widgets/forum_split_pane_divider.dart';
import '../widgets/hide_forum_confirm_dialog.dart';
import '../widgets/thread_detail_chrome_bridge.dart';
import '../models/favorite_item.dart';
import '../models/new_thread_submit_result.dart';
import '../models/thread.dart';
import '../models/thread_list_query.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_fab_layout.dart';
import '../widgets/s1_list_boundary_footer.dart';
import '../widgets/s1_local_search_bar.dart';
import '../widgets/s1_menu.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/thread_context_sheet.dart';
import '../widgets/thread_card.dart';
import '../widgets/skeleton/s1_async_list_loading.dart';
import '../widgets/skeleton/thread_card_skeleton.dart';
import '../utils/page_search.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/forum_list_layout.dart';
import '../models/thread_open_intent.dart';
import '../models/thread_destination.dart';
import '../utils/thread_navigation.dart';
import '../theme/s1_haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/thread_open_intent_scope.dart';

class ForumListScreen extends ConsumerStatefulWidget {
  const ForumListScreen({
    super.key,
    required this.fid,
    this.selectedThreadId,
    this.selectedThreadIntent,
  });
  final String fid;
  final String? selectedThreadId;
  final ThreadOpenIntent? selectedThreadIntent;

  @override
  ConsumerState<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends ConsumerState<ForumListScreen> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();
  final _detailChrome = ThreadDetailChromeBridge();
  bool _showScrollToTop = false;
  bool _pageSearchOpen = false;
  String _pageSearchQuery = '';
  double? _dragListPaneWidth;

  @override
  void dispose() {
    _detailChrome.dispose();
    super.dispose();
  }

  void _openThread(
    ThreadDestination destination, {
    int? resumePageHint,
  }) {
    // 同一 forum 页面改查询参数时用 go，避免叠两层同 path（pageKey 虽唯一，
    // 也不应把双栏状态拆成两条历史）。
    context.go(
      ThreadRouteCodec.encodeForumPath(
        widget.fid,
        destination,
        resumePageHint: resumePageHint,
      ),
    );
  }

  void _onScrollMetricsChanged(S1ScrollMetrics metrics) {
    final show = S1FabLayout.shouldShowScrollToTop(
      metrics: metrics,
      currentlyShowing: _showScrollToTop,
    );
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  Future<void> _openNewThread() async {
    final result = await context.push<NewThreadSubmitResult>(
      '/forum/${widget.fid}/new-thread',
    );
    if (!mounted || result == null || !result.isSuccess) return;
    S1SnackBar.show(
      context,
      message: '发帖成功',
      feedback: S1SnackBarFeedback.success,
    );
    await ref.read(threadListProvider(widget.fid).notifier).refresh();
    if (mounted) unawaited(context.push('/thread/${result.tid}'));
  }

  void _closeSplitDetail() {
    context.replace('/forum/${widget.fid}');
  }

  bool _acceptsGlobalShortcut() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext == null ||
        (focusContext.widget is! EditableText &&
            focusContext.findAncestorWidgetOfExactType<EditableText>() == null);
  }

  void _selectAdjacentThread(int delta) {
    final state = ref.read(threadListProvider(widget.fid)).asData?.value;
    final selectedId = widget.selectedThreadId;
    if (state == null || selectedId == null) return;
    final threads = state.threads;
    final index = threads.indexWhere((t) => t.tid == selectedId);
    if (index < 0) return;
    final next = index + delta;
    if (next < 0 || next >= threads.length) return;
    _openThread(ResumeThread(threads[next].tid));
  }

  void _onListPaneDragDelta(double delta, double availableWidth) {
    final stored = ref.read(settingsProvider).forumSplitListPaneWidth;
    final current =
        _dragListPaneWidth ?? stored ?? forumListPaneWidth(availableWidth);
    setState(() {
      _dragListPaneWidth = forumListPaneWidth(
        availableWidth,
        userOverride: current + delta,
      );
    });
  }

  void _persistListPaneWidth(double availableWidth) {
    final width = _dragListPaneWidth;
    if (width == null) return;
    ref.read(settingsProvider.notifier).setForumSplitListPaneWidth(width);
    setState(() => _dragListPaneWidth = null);
  }

  double _resolveListPaneWidth(double availableWidth) {
    final stored = ref.watch(
      settingsProvider.select((s) => s.forumSplitListPaneWidth),
    );
    return forumListPaneWidth(
      availableWidth,
      userOverride: _dragListPaneWidth ?? stored,
    );
  }

  List<Widget> _buildSplitDetailAppBarActions(
    ThreadDetailChromeSnapshot? chrome,
  ) {
    if (chrome == null || chrome.shareSelectMode) {
      return const [];
    }
    return [
      FavoriteBookmarkButton(
        type: FavoriteType.thread,
        id: widget.selectedThreadId!,
      ),
      if (chrome.onRefresh != null &&
          chrome.onTogglePageSearch != null &&
          chrome.browserUrl != null)
        AppBarMoreMenu(
          onRefresh: chrome.onRefresh!,
          onPageSearch: chrome.onTogglePageSearch!,
          pageSearchOpen: chrome.pageSearchOpen,
          onGoToLatest: chrome.onGoToLatest,
          isPinned: chrome.isPinned,
          onTogglePin: chrome.onTogglePin,
          browserUrl: chrome.browserUrl!,
          postListDensity: chrome.postListDensity,
          onPostListDensityChanged: chrome.onPostListDensityChanged,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = threadListProvider(widget.fid);
    final threadsAsync = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      final previousMessage = previous?.asData?.value.errorMessage;
      final message = next.asData?.value.errorMessage;
      if (message != null && message != previousMessage) {
        S1SnackBar.show(context, message: '加载失败：$message');
      }
    });
    final forum = ref.watch(forumNameProvider(widget.fid)) ??
        threadsAsync.asData?.value.forumName ??
        '';
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final windowWidth = MediaQuery.sizeOf(context).width;
    final isSplit = shouldShowForumSplitView(
      windowWidth,
      hasSelectedThread: widget.selectedThreadId != null,
    );
    final selectedThreadId = widget.selectedThreadId;
    final postsAsync = isSplit && selectedThreadId != null
        ? ref.watch(postProvider(selectedThreadId))
        : null;
    final threadTitle = postsAsync?.asData?.value.threadSubject;
    final floorSubtitle =
        isSplit ? _splitFloorSubtitle(postsAsync?.asData?.value) : null;

    if (!shouldOpenForumThreadInPlace(windowWidth) &&
        widget.selectedThreadId != null) {
      return ThreadOpenIntentScope(
        tid: widget.selectedThreadId!,
        intent: widget.selectedThreadIntent,
        child: ThreadDetailScreen(
          tid: widget.selectedThreadId!,
          onClose: () => context.replace('/forum/${widget.fid}'),
          onDestinationChanged: (destination) => context.replace(
            ThreadRouteCodec.encodeForumPath(widget.fid, destination),
          ),
        ),
      );
    }

    final scaffold = Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: isSplit
            ? ListenableBuilder(
                listenable: _detailChrome,
                builder: (context, _) {
                  final chrome = _detailChrome.snapshot;
                  if (chrome?.shareSelectMode ?? false) {
                    return const Text('选择分享楼层');
                  }
                  return ForumSplitBreadcrumbTitle(
                    forumLabel: forum.isNotEmpty ? forum : '版块 #${widget.fid}',
                    threadTitle: threadTitle,
                    floorContext: floorSubtitle,
                    loading: postsAsync?.isLoading ?? false,
                    onForumTap: _closeSplitDetail,
                    onThreadTap: threadTitle == null
                        ? null
                        : () => showThreadFullTitleSheet(
                              context,
                              threadTitle,
                            ),
                  );
                },
              )
            : Text(forum.isNotEmpty ? forum : '版块 #${widget.fid}'),
        actions: isSplit
            ? [
                FavoriteBookmarkButton(
                  type: FavoriteType.forum,
                  id: widget.fid,
                ),
                ListenableBuilder(
                  listenable: _detailChrome,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildSplitDetailAppBarActions(
                      _detailChrome.snapshot,
                    ),
                  ),
                ),
              ]
            : [
                FavoriteBookmarkButton(
                  type: FavoriteType.forum,
                  id: widget.fid,
                ),
                AppBarMoreMenu(
                  onRefresh: () => ref
                      .read(threadListProvider(widget.fid).notifier)
                      .refresh(),
                  onPageSearch: () {
                    setState(() {
                      _pageSearchOpen = !_pageSearchOpen;
                      if (!_pageSearchOpen) _pageSearchQuery = '';
                    });
                  },
                  pageSearchOpen: _pageSearchOpen,
                  browserUrl: ApiConfig.forumBrowserUrl(
                    fid: widget.fid,
                    page: threadsAsync.asData?.value.currentPage ?? 1,
                  ),
                  threadListDensity: ref.watch(
                    settingsProvider.select((s) => s.threadListDensity),
                  ),
                  onThreadListDensityChanged: (density) => ref
                      .read(settingsProvider.notifier)
                      .setThreadListDensity(density),
                  hideStickyThreads: ref.watch(
                    settingsProvider.select(
                      (s) => s.hideStickyEffectiveFor(widget.fid),
                    ),
                  ),
                  onToggleHideStickyThreads: () => ref
                      .read(settingsProvider.notifier)
                      .toggleHideStickyForum(widget.fid),
                  onHideForum: () async {
                    final confirmed = await confirmHideForum(context);
                    if (!confirmed || !context.mounted) return;
                    ref.read(settingsProvider.notifier).hideForum(widget.fid);
                    S1SnackBar.show(context, message: '已屏蔽此版块');
                  },
                ),
              ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final opensThreadInPlace = shouldOpenForumThreadInPlace(windowWidth);
          final listPaneWidth =
              isSplit ? _resolveListPaneWidth(constraints.maxWidth) : null;
          final splitBody = Row(
            children: [
              if (isSplit)
                ColoredBox(
                  color: S1Surface.page(Theme.of(context).colorScheme),
                  child: SizedBox(
                    width: listPaneWidth,
                    child: Column(
                      children: [
                        if (_pageSearchOpen)
                          S1LocalSearchBar(
                            hintText: '搜索本页主题 / 作者',
                            query: _pageSearchQuery,
                            onChanged: (q) =>
                                setState(() => _pageSearchQuery = q),
                            onClose: () => setState(() {
                              _pageSearchOpen = false;
                              _pageSearchQuery = '';
                            }),
                            matchCount: threadsAsync.asData == null
                                ? null
                                : _filterThreads(
                                    threadsAsync.asData!.value.threads,
                                    _pageSearchQuery,
                                  ).length,
                          ),
                        Expanded(
                          child: threadsAsync.when(
                            loading: () => const S1AsyncListLoading(
                              child: ThreadCardSkeletonList(),
                            ),
                            error: (e, st) => S1ErrorView(
                              error: e,
                              onRetry: () => S1Haptics.wrapRefresh(
                                () => ref
                                    .read(
                                      threadListProvider(widget.fid).notifier,
                                    )
                                    .refresh(),
                              ),
                              onLogin: () => context.push('/login'),
                            ),
                            data: (state) => _ForumThreadList(
                              state: state,
                              isLoggedIn: isLoggedIn,
                              fid: widget.fid,
                              selectedThreadId: widget.selectedThreadId,
                              swipeKey: _swipeKey,
                              showScrollToTop: _showScrollToTop,
                              onScrollMetricsChanged: _onScrollMetricsChanged,
                              onOpenNewThread: _openNewThread,
                              onOpenThread: _openThread,
                              onPageChanged: (page) => ref
                                  .read(
                                    threadListProvider(widget.fid).notifier,
                                  )
                                  .goToPage(page),
                              pageSearchQuery: _pageSearchQuery,
                              useSplitFab: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: S1ContentWidth(
                    child: Column(
                      children: [
                        if (_pageSearchOpen)
                          S1LocalSearchBar(
                            hintText: '搜索本页主题 / 作者',
                            query: _pageSearchQuery,
                            onChanged: (q) =>
                                setState(() => _pageSearchQuery = q),
                            onClose: () => setState(() {
                              _pageSearchOpen = false;
                              _pageSearchQuery = '';
                            }),
                            matchCount: threadsAsync.asData == null
                                ? null
                                : _filterThreads(
                                    threadsAsync.asData!.value.threads,
                                    _pageSearchQuery,
                                  ).length,
                          ),
                        Expanded(
                          child: threadsAsync.when(
                            loading: () => const S1AsyncListLoading(
                              child: ThreadCardSkeletonList(),
                            ),
                            error: (e, st) => S1ErrorView(
                              error: e,
                              onRetry: () => S1Haptics.wrapRefresh(
                                () => ref
                                    .read(
                                      threadListProvider(widget.fid).notifier,
                                    )
                                    .refresh(),
                              ),
                              onLogin: () => context.push('/login'),
                            ),
                            data: (state) => _ForumThreadList(
                              state: state,
                              isLoggedIn: isLoggedIn,
                              fid: widget.fid,
                              selectedThreadId: widget.selectedThreadId,
                              swipeKey: _swipeKey,
                              showScrollToTop: _showScrollToTop,
                              onScrollMetricsChanged: _onScrollMetricsChanged,
                              onOpenNewThread: _openNewThread,
                              onOpenThread:
                                  opensThreadInPlace ? _openThread : null,
                              onPageChanged: (page) => ref
                                  .read(
                                    threadListProvider(widget.fid).notifier,
                                  )
                                  .goToPage(page),
                              pageSearchQuery: _pageSearchQuery,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isSplit) ...[
                ForumSplitPaneDivider(
                  onDragDelta: (delta) => _onListPaneDragDelta(
                    delta,
                    constraints.maxWidth,
                  ),
                ),
                Expanded(
                  child: ThreadOpenIntentScope(
                    tid: widget.selectedThreadId!,
                    intent: widget.selectedThreadIntent,
                    child: ThreadDetailScreen(
                      key: ValueKey(widget.selectedThreadId),
                      tid: widget.selectedThreadId!,
                      embedded: true,
                      suppressAppBar: true,
                      chromeBridge: _detailChrome,
                      onClose: _closeSplitDetail,
                      onDestinationChanged: (destination) => context.replace(
                        ThreadRouteCodec.encodeForumPath(
                          widget.fid,
                          destination,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
          if (!isSplit) return splitBody;
          return Listener(
            onPointerUp: (_) => _persistListPaneWidth(constraints.maxWidth),
            child: splitBody,
          );
        },
      ),
    );

    final child = isSplit
        ? CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_acceptsGlobalShortcut()) _closeSplitDetail();
              },
              const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () {
                if (_acceptsGlobalShortcut()) _selectAdjacentThread(-1);
              },
              const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
                  () {
                if (_acceptsGlobalShortcut()) _selectAdjacentThread(1);
              },
              const SingleActivator(LogicalKeyboardKey.bracketLeft, alt: true):
                  () {
                final chrome = _detailChrome.snapshot;
                if (_acceptsGlobalShortcut() && chrome?.canPrevPage == true) {
                  chrome!.onPrevPage?.call();
                }
              },
              const SingleActivator(LogicalKeyboardKey.bracketRight, alt: true):
                  () {
                final chrome = _detailChrome.snapshot;
                if (_acceptsGlobalShortcut() && chrome?.canNextPage == true) {
                  chrome!.onNextPage?.call();
                }
              },
            },
            child: Focus(autofocus: true, child: scaffold),
          )
        : scaffold;

    return S1DesktopScaffold(
      highlightedTab: 0,
      child: child,
    );
  }
}

String? _splitFloorSubtitle(PostListState? state) {
  if (state == null) return null;
  if (state.totalPages <= 1 && state.totalReplies <= 0) return null;
  final floors = state.totalReplies + 1;
  return '第 ${state.currentPage} / ${state.totalPages} 页 · 共 $floors 楼';
}

List<Thread> _filterThreads(List<Thread> threads, String query) {
  return PageSearch.filterByQuery(
    threads,
    query,
    (t) => [
      t.subject,
      t.author,
      if (t.lastPoster != null) t.lastPoster!,
      if (t.typeName != null) t.typeName!,
    ],
  );
}

class _ForumThreadList extends ConsumerWidget {
  const _ForumThreadList({
    required this.state,
    required this.isLoggedIn,
    required this.fid,
    required this.selectedThreadId,
    required this.swipeKey,
    required this.showScrollToTop,
    required this.onScrollMetricsChanged,
    required this.onOpenNewThread,
    required this.onOpenThread,
    required this.onPageChanged,
    this.pageSearchQuery = '',
    this.useSplitFab = false,
  });

  final ThreadListState state;
  final bool isLoggedIn;
  final String fid;
  final String? selectedThreadId;
  final GlobalKey<S1SwipePaginationState> swipeKey;
  final bool showScrollToTop;
  final ValueChanged<S1ScrollMetrics> onScrollMetricsChanged;
  final Future<void> Function() onOpenNewThread;
  final ThreadOpenCallback? onOpenThread;
  final S1PageChangeCallback onPageChanged;
  final String pageSearchQuery;
  final bool useSplitFab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = _filterThreads(state.threads, pageSearchQuery);
    final hasQuery = PageSearch.normalizeQuery(pageSearchQuery).isNotEmpty;
    final listDensity = ref.watch(
      settingsProvider.select((s) => s.threadListDensity),
    );
    final chipTokens = ThreadCardDensityTokens.forDensity(listDensity);

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 翻页 / 筛选共用一条；关闭 S1SwipePagination 自带条，避免筛选栏上下各一条。
        if (state.isLoading)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: scheme.surfaceContainer,
            color: scheme.primary,
          ),
        _ThreadFiltersSection(
          query: state.query,
          threadTypes: state.threadTypes,
          selectedTypeId: state.selectedTypeId,
          enabled: !state.isLoading,
          chipVisualDensity: chipTokens.categoryChipVisualDensity,
          chipLabelPadding: chipTokens.categoryChipLabelPadding,
          barPadding: chipTokens.categoryFilterBarPadding,
          onQueryChanged: (query) =>
              ref.read(threadListProvider(fid).notifier).setQuery(query),
          onTypeSelected: (typeId) =>
              ref.read(threadListProvider(fid).notifier).selectType(typeId),
        ),
        Expanded(
          child: S1ContentFabOverlay(
            fab: S1FabStack(
              primary: isLoggedIn
                  ? S1FabItem(
                      heroTag: 'newThread-$fid',
                      icon: useSplitFab ? Icons.add : Icons.create_outlined,
                      tooltip: '发新主题',
                      label: useSplitFab ? '发新主题' : null,
                      extended: useSplitFab,
                      onPressed: () => unawaited(onOpenNewThread()),
                    )
                  : null,
              scrollNav: S1ScrollNavConfig(
                showScrollToTop: showScrollToTop,
                showScrollAdvance: false,
                onScrollToTop: () => swipeKey.currentState?.scrollToTop(),
              ),
            ),
            child: S1SwipePagination(
              key: swipeKey,
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              showPagingIndicator: false,
              onScrollMetricsChanged: onScrollMetricsChanged,
              onPageChanged: onPageChanged,
              pageBuilder: (context, scrollController) => Scrollbar(
                controller: scrollController,
                child: RefreshIndicator(
                  onRefresh: () => S1Haptics.wrapRefresh(
                    () => ref.read(threadListProvider(fid).notifier).refresh(),
                  ),
                  child: state.threads.isEmpty
                      ? ListView(
                          controller: scrollController,
                          children: [
                            const SizedBox(height: 48),
                            Center(
                              child: Text(
                                state.selectedTypeId != null
                                    ? '该分类暂无帖子'
                                    : !state.query.isDefault
                                        ? '当前筛选暂无帖子'
                                        : '暂无帖子',
                              ),
                            ),
                          ],
                        )
                      : threads.isEmpty && hasQuery
                          ? ListView(
                              controller: scrollController,
                              children: const [
                                SizedBox(height: 48),
                                Center(child: Text('本页无匹配主题')),
                              ],
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: S1FabLayout.scrollBottomPadding,
                              itemCount: threads.length + 1,
                              itemBuilder: (context, index) {
                                if (index >= threads.length) {
                                  return S1ListBoundaryFooter(
                                    kind: pagedBoundaryKind(
                                      currentPage: state.currentPage,
                                      totalPages: state.totalPages,
                                    ),
                                  );
                                }
                                final thread = threads[index];
                                return RepaintBoundary(
                                  key: ValueKey('thread_card_${thread.tid}'),
                                  child: GestureDetector(
                                    onLongPress: () {
                                      S1Haptics.selection();
                                      showThreadContextSheet(
                                        context: context,
                                        ref: ref,
                                        thread: thread,
                                        onOpenThread: onOpenThread,
                                      );
                                    },
                                    child: ThreadCard(
                                      key: ValueKey(thread.tid),
                                      thread: thread,
                                      selected: thread.tid == selectedThreadId,
                                      onOpenThread: onOpenThread,
                                      selectedTypeId: state.selectedTypeId,
                                      onTypeFilter: (typeId) => ref
                                          .read(
                                            threadListProvider(fid).notifier,
                                          )
                                          .selectType(typeId),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ),
          ),
        ),
        PaginationBar(
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          sheetTitle: useSplitFab ? '选择主题页' : '选择页码',
          contextLabel: useSplitFab ? '主题' : null,
          contextTooltip: useSplitFab ? '主题列表分页' : null,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _ThreadFiltersSection extends ConsumerWidget {
  const _ThreadFiltersSection({
    required this.query,
    required this.threadTypes,
    required this.selectedTypeId,
    required this.enabled,
    required this.chipVisualDensity,
    required this.chipLabelPadding,
    required this.barPadding,
    required this.onQueryChanged,
    required this.onTypeSelected,
  });

  final ThreadListQuery query;
  final Map<String, String> threadTypes;
  final String? selectedTypeId;
  final bool enabled;
  final VisualDensity chipVisualDensity;
  final EdgeInsetsGeometry chipLabelPadding;
  final EdgeInsets barPadding;
  final ValueChanged<ThreadListQuery> onQueryChanged;
  final ValueChanged<String?> onTypeSelected;

  void _toggleExpanded(WidgetRef ref, bool expanded) {
    S1Haptics.selection();
    ref.read(settingsProvider.notifier).setThreadListFiltersExpanded(!expanded);
  }

  bool _hasActiveFilters(String? typeName) {
    final hasType = typeName != null && typeName.trim().isNotEmpty;
    return !query.isDefault || hasType;
  }

  void _resetFilters() {
    onQueryChanged(ThreadListQuery.defaults);
    onTypeSelected(null);
  }

  List<Widget> _buildSummaryActions(
    BuildContext context, {
    required String? typeName,
    required bool enabled,
  }) {
    final chips = <Widget>[];

    void addChip({
      required String label,
      required VoidCallback? onPressed,
      required String tooltip,
      required IconData icon,
    }) {
      chips.add(
        Tooltip(
          message: tooltip,
          child: ActionChip(
            avatar: Icon(icon, size: 16),
            label: Text(label),
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    if (query.preset != ThreadListSortPreset.all) {
      addChip(
        label: query.preset.label,
        tooltip: '点按恢复为全部主题',
        icon: Icons.sort,
        onPressed: enabled
            ? () => onQueryChanged(
                  query.copyWith(preset: ThreadListSortPreset.all),
                )
            : null,
      );
    }
    if (query.hasTimeFilter) {
      addChip(
        label: query.timeLabel,
        tooltip: '点按恢复为全部时间',
        icon: Icons.schedule_outlined,
        onPressed: enabled
            ? () => onQueryChanged(query.copyWith(datelineSeconds: 0))
            : null,
      );
    }
    final trimmedType = typeName?.trim();
    if (trimmedType != null && trimmedType.isNotEmpty) {
      addChip(
        label: trimmedType,
        tooltip: '点按清除分类筛选',
        icon: Icons.label_outline,
        onPressed: enabled ? () => onTypeSelected(null) : null,
      );
    }

    return chips;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(
      settingsProvider.select((s) => s.threadListFiltersExpanded),
    );
    final typeName =
        selectedTypeId == null ? null : threadTypes[selectedTypeId];
    final summary = threadListFilterSummary(
      query: query,
      typeName: typeName,
    );
    final summaryActions = _buildSummaryActions(
      context,
      typeName: typeName,
      enabled: enabled,
    );
    final hasActiveFilters = _hasActiveFilters(typeName);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semanticsLabel = expanded ? '筛选（已展开）' : '筛选（已收起）';
    final semanticsHint = expanded ? '双击收起筛选' : '双击展开筛选';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          expanded: expanded,
          label: semanticsLabel,
          hint: semanticsHint,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => _toggleExpanded(ref, expanded) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    barPadding.left,
                    4,
                    barPadding.right,
                    4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: expanded || summaryActions.isEmpty
                            ? Text(
                                summary,
                                style: textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: summaryActions,
                              ),
                      ),
                      if (hasActiveFilters)
                        IconButton(
                          tooltip: '重置筛选',
                          icon: const Icon(Icons.restart_alt),
                          color: scheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          onPressed: enabled ? _resetFilters : null,
                        ),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ThreadSortFilterBar(
                      query: query,
                      enabled: enabled,
                      chipVisualDensity: chipVisualDensity,
                      chipLabelPadding: chipLabelPadding,
                      barPadding: barPadding,
                      onChanged: onQueryChanged,
                    ),
                    if (threadTypes.isNotEmpty)
                      _ThreadTypeFilterBar(
                        threadTypes: threadTypes,
                        selectedTypeId: selectedTypeId,
                        enabled: enabled,
                        chipVisualDensity: chipVisualDensity,
                        chipLabelPadding: chipLabelPadding,
                        barPadding: barPadding,
                        onSelected: onTypeSelected,
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ThreadSortFilterBar extends StatelessWidget {
  const _ThreadSortFilterBar({
    required this.query,
    required this.enabled,
    required this.chipVisualDensity,
    required this.chipLabelPadding,
    required this.barPadding,
    required this.onChanged,
  });

  final ThreadListQuery query;
  final bool enabled;
  final VisualDensity chipVisualDensity;
  final EdgeInsetsGeometry chipLabelPadding;
  final EdgeInsets barPadding;
  final ValueChanged<ThreadListQuery> onChanged;

  String get _moreLabel {
    if (!query.preset.isPrimaryChip) return query.preset.label;
    if (query.hasTimeFilter) return query.timeLabel;
    return '更多';
  }

  bool get _moreSelected => !query.preset.isPrimaryChip || query.hasTimeFilter;

  IconData _sortIcon(ThreadListSortPreset preset) {
    return switch (preset) {
      ThreadListSortPreset.newest => Icons.edit_calendar_outlined,
      ThreadListSortPreset.replies => Icons.chat_bubble_outline,
      ThreadListSortPreset.views => Icons.visibility_outlined,
      _ => Icons.sort,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sectionStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: barPadding,
      child: Row(
        children: [
          for (final preset in threadListPrimaryPresets)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(preset.label),
                selected: query.preset == preset && preset.isPrimaryChip,
                showCheckmark: false,
                side: BorderSide.none,
                visualDensity: chipVisualDensity,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: chipLabelPadding,
                padding: EdgeInsets.zero,
                onSelected: enabled
                    ? (_) => onChanged(query.copyWith(preset: preset))
                    : null,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: MenuAnchor(
              style: S1MenuSpec.anchoredMenuStyle(context),
              alignmentOffset: S1MenuSpec.underAnchorOffset(context),
              reservedPadding: S1MenuSpec.reservedPadding,
              crossAxisUnconstrained: false,
              builder: (context, controller, child) {
                return Semantics(
                  button: true,
                  enabled: enabled,
                  label: '更多筛选，当前：$_moreLabel',
                  hint: '双击打开排序和时间菜单',
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_moreLabel),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    selected: _moreSelected,
                    showCheckmark: false,
                    side: BorderSide.none,
                    visualDensity: chipVisualDensity,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: chipLabelPadding,
                    padding: EdgeInsets.zero,
                    onSelected: enabled
                        ? (_) {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          }
                        : null,
                  ),
                );
              },
              menuChildren: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    S1MenuSpec.itemHorizontalPadding,
                    12,
                    S1MenuSpec.itemHorizontalPadding,
                    4,
                  ),
                  child: Text('排序', style: sectionStyle),
                ),
                for (final preset in threadListMoreSortPresets)
                  s1MenuItem(
                    icon: _sortIcon(preset),
                    label: preset.label,
                    selected: query.preset == preset,
                    onPressed: enabled
                        ? () => onChanged(query.copyWith(preset: preset))
                        : null,
                  ),
                const S1MenuDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    S1MenuSpec.itemHorizontalPadding,
                    4,
                    S1MenuSpec.itemHorizontalPadding,
                    4,
                  ),
                  child: Text('时间', style: sectionStyle),
                ),
                for (final option in threadListTimeOptions)
                  s1MenuItem(
                    icon: Icons.schedule_outlined,
                    label: option.label,
                    selected: query.datelineSeconds == option.seconds,
                    onPressed: enabled
                        ? () => onChanged(
                              query.copyWith(datelineSeconds: option.seconds),
                            )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTypeFilterBar extends StatelessWidget {
  const _ThreadTypeFilterBar({
    required this.threadTypes,
    required this.selectedTypeId,
    required this.enabled,
    required this.chipVisualDensity,
    required this.chipLabelPadding,
    required this.barPadding,
    required this.onSelected,
  });

  final Map<String, String> threadTypes;
  final String? selectedTypeId;
  final bool enabled;
  final VisualDensity chipVisualDensity;
  final EdgeInsetsGeometry chipLabelPadding;
  final EdgeInsets barPadding;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: barPadding,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('全部'),
              selected: selectedTypeId == null,
              showCheckmark: false,
              side: BorderSide.none,
              visualDensity: chipVisualDensity,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: chipLabelPadding,
              padding: EdgeInsets.zero,
              onSelected: enabled ? (_) => onSelected(null) : null,
            ),
          ),
          for (final entry in threadTypes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(entry.value),
                selected: selectedTypeId == entry.key,
                showCheckmark: false,
                side: BorderSide.none,
                visualDensity: chipVisualDensity,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: chipLabelPadding,
                padding: EdgeInsets.zero,
                onSelected: enabled ? (_) => onSelected(entry.key) : null,
              ),
            ),
        ],
      ),
    );
  }
}
