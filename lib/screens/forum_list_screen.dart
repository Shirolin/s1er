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
import '../providers/thread_list_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/favorite_bookmark_button.dart';
import '../models/favorite_item.dart';
import '../models/new_thread_submit_result.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_fab_layout.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/thread_card.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/forum_list_layout.dart';
import '../models/thread_open_intent.dart';
import '../models/thread_destination.dart';
import '../providers/thread_open_intent_provider.dart';
import '../utils/thread_navigation.dart';

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

  void _openThread(
    ThreadDestination destination, {
    int? resumePageHint,
  }) {
    context.push(
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
      return ProviderScope(
        overrides: [
          threadOpenIntentProvider(widget.selectedThreadId!).overrideWithValue(
            widget.selectedThreadIntent,
          ),
        ],
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
              browserUrl: '${ApiConfig.baseUrl}/forum-${widget.fid}-1.html',
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
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
                    width: 380,
                    child: threadsAsync.when(
                      loading: () => const Column(
                        children: [
                          LinearProgressIndicator(),
                          Expanded(child: SizedBox()),
                        ],
                      ),
                      error: (e, st) => S1ErrorView(
                        error: e,
                        onRetry: () => ref
                            .read(threadListProvider(widget.fid).notifier)
                            .refresh(),
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
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: S1ContentWidth(
                      child: threadsAsync.when(
                        loading: () => const Column(
                          children: [
                            LinearProgressIndicator(),
                            Expanded(child: SizedBox()),
                          ],
                        ),
                        error: (e, st) => S1ErrorView(
                          error: e,
                          onRetry: () => ref
                              .read(threadListProvider(widget.fid).notifier)
                              .refresh(),
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
                          onOpenThread: opensThreadInPlace ? _openThread : null,
                          onPageChanged: (page) => ref
                              .read(threadListProvider(widget.fid).notifier)
                              .goToPage(page),
                        ),
                      ),
                    ),
                  ),
                if (isSplit) ...[
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: ProviderScope(
                      overrides: [
                        threadOpenIntentProvider(widget.selectedThreadId!)
                            .overrideWithValue(widget.selectedThreadIntent),
                      ],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onRefresh: () =>
                      ref.read(threadListProvider(fid).notifier).refresh(),
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
                      : ListView.builder(
                          controller: scrollController,
                          padding: S1FabLayout.scrollBottomPadding,
                          itemCount: state.threads.length,
                          itemBuilder: (context, index) {
                            final thread = state.threads[index];
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
              onSelected: enabled ? (_) => onSelected(null) : null,
            ),
          ),
          for (final entry in threadTypes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(entry.value),
                selected: selectedTypeId == entry.key,
                onSelected: enabled ? (_) => onSelected(entry.key) : null,
              ),
            ),
        ],
      ),
    );
  }
}
