import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../widgets/s1_desktop_scaffold.dart';
import '../widgets/s1_content_width.dart';
import 'thread_detail_screen.dart';
import '../providers/forum_name_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_list_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/favorite_bookmark_button.dart';
import '../widgets/hide_forum_confirm_dialog.dart';
import '../models/favorite_item.dart';
import '../models/new_thread_submit_result.dart';
import '../models/thread.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_fab_layout.dart';
import '../widgets/s1_list_boundary_footer.dart';
import '../widgets/s1_local_search_bar.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/thread_card.dart';
import '../utils/page_search.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/forum_list_layout.dart';
import '../models/thread_open_intent.dart';
import '../models/thread_destination.dart';
import '../utils/thread_navigation.dart';
import '../theme/s1_haptics.dart';
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
  bool _showScrollToTop = false;
  bool _pageSearchOpen = false;
  String _pageSearchQuery = '';

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
    await ref.read(threadListProvider(widget.fid).notifier).refresh();
    if (mounted) unawaited(context.push('/thread/${result.tid}'));
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

    return S1DesktopScaffold(
      highlightedTab: 0,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(forum.isNotEmpty ? forum : '版块 #${widget.fid}'),
          actions: [
            FavoriteBookmarkButton(
              type: FavoriteType.forum,
              id: widget.fid,
            ),
            AppBarMoreMenu(
              onRefresh: () =>
                  ref.read(threadListProvider(widget.fid).notifier).refresh(),
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
            final opensThreadInPlace =
                shouldOpenForumThreadInPlace(windowWidth);
            final isSplit = shouldShowForumSplitView(
              windowWidth,
              hasSelectedThread: widget.selectedThreadId != null,
            );
            return Row(
              children: [
                if (isSplit)
                  SizedBox(
                    width: forumListPaneWidth(constraints.maxWidth),
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
                            loading: () => const Column(
                              children: [
                                LinearProgressIndicator(),
                                Expanded(child: SizedBox()),
                              ],
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
                                  .read(threadListProvider(widget.fid).notifier)
                                  .goToPage(page),
                              pageSearchQuery: _pageSearchQuery,
                            ),
                          ),
                        ),
                      ],
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
                              loading: () => const Column(
                                children: [
                                  LinearProgressIndicator(),
                                  Expanded(child: SizedBox()),
                                ],
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: ThreadOpenIntentScope(
                      tid: widget.selectedThreadId!,
                      intent: widget.selectedThreadIntent,
                      child: ThreadDetailScreen(
                        key: ValueKey(widget.selectedThreadId),
                        tid: widget.selectedThreadId!,
                        embedded: true,
                        onClose: () => context.replace('/forum/${widget.fid}'),
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
          },
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = _filterThreads(state.threads, pageSearchQuery);
    final hasQuery = PageSearch.normalizeQuery(pageSearchQuery).isNotEmpty;

    return Column(
      children: [
        if (state.isLoading) const LinearProgressIndicator(),
        if (state.threadTypes.isNotEmpty)
          _ThreadTypeFilterBar(
            threadTypes: state.threadTypes,
            selectedTypeId: state.selectedTypeId,
            enabled: !state.isLoading,
            onSelected: (typeId) =>
                ref.read(threadListProvider(fid).notifier).selectType(typeId),
          ),
        Expanded(
          child: S1ContentFabOverlay(
            fab: S1FabStack(
              primary: isLoggedIn
                  ? S1FabItem(
                      heroTag: 'newThread-$fid',
                      icon: Icons.create_outlined,
                      tooltip: '发新主题',
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
                                state.selectedTypeId == null
                                    ? '暂无帖子'
                                    : '该分类暂无帖子',
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
                                  child: ThreadCard(
                                    key: ValueKey(thread.tid),
                                    thread: thread,
                                    selected: thread.tid == selectedThreadId,
                                    onOpenThread: onOpenThread,
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
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _ThreadTypeFilterBar extends StatelessWidget {
  const _ThreadTypeFilterBar({
    required this.threadTypes,
    required this.selectedTypeId,
    required this.enabled,
    required this.onSelected,
  });

  final Map<String, String> threadTypes;
  final String? selectedTypeId;
  final bool enabled;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('全部'),
              selected: selectedTypeId == null,
              showCheckmark: true,
              side: BorderSide.none,
              onSelected: enabled ? (_) => onSelected(null) : null,
            ),
          ),
          for (final entry in threadTypes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(entry.value),
                selected: selectedTypeId == entry.key,
                showCheckmark: true,
                side: BorderSide.none,
                onSelected: enabled ? (_) => onSelected(entry.key) : null,
              ),
            ),
        ],
      ),
    );
  }
}
