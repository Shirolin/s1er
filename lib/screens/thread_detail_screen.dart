import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../models/blacklist_record.dart';
import '../models/post.dart';
import '../models/reply_submit_result.dart';
import '../models/edit_post_submit_result.dart';
import '../providers/blacklist_provider.dart';
import '../providers/post_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_history_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/compose_draft_store.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/favorite_bookmark_button.dart';
import '../models/favorite_item.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_item.dart';
import '../widgets/poll_card.dart';
import '../widgets/rate_dialog.dart';
import '../widgets/report_dialog.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_fab_layout.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/s1_desktop_scaffold.dart';
import '../models/open_scroll_target.dart';
import '../models/thread_destination.dart';
import '../utils/scroll_floor.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/thread_navigation.dart';
import '../providers/post_share_provider.dart';
import '../theme/app_theme.dart';

bool shouldRecordReadingProgress(AppSettings settings, AuthState auth) {
  if (!settings.recordReadingHistory) {
    return false;
  }
  if (auth.isLoggedIn && (auth.user?.uid.isEmpty ?? true)) {
    return false;
  }
  return true;
}

/// 仅在首访、翻页或页内可见楼变化时写库。
bool shouldWriteReadingProgressUpdate({
  required bool hasRecordedInitialVisit,
  required int? lastRecordedPage,
  required int? lastRecordedFloorInPage,
  required int currentPage,
  required int currentFloorInPage,
}) {
  if (!hasRecordedInitialVisit) return true;
  if (lastRecordedPage != currentPage) return true;
  return lastRecordedFloorInPage != currentFloorInPage;
}

/// 滚动 FAB 显隐状态（用 [ValueNotifier] 更新，避免重建列表）。
class _ScrollFabVisibility {
  const _ScrollFabVisibility({
    this.showScrollToTop = false,
    this.showScrollDown = false,
    this.atPageBottom = false,
  });

  final bool showScrollToTop;
  final bool showScrollDown;
  final bool atPageBottom;
}

class ThreadDetailScreen extends ConsumerStatefulWidget {
  const ThreadDetailScreen({
    super.key,
    required this.tid,
  });
  final String tid;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();
  final _scrollFabVisibility = ValueNotifier(const _ScrollFabVisibility());
  bool _hasRecordedInitialVisit = false;
  int? _lastRecordedPage;
  int? _lastRecordedFloorInPage;
  bool _pendingInitialNavigation = false;
  bool _openScrollConsumed = false;
  String? _highlightPid;
  String? _shownLocateError;

  /// 用户手动翻页后为 true，此时不再消费 openScrollTarget。
  bool _manualPageChange = false;

  /// 当前页各楼 PostItem 的 key（不含 PollCard），翻页时重建。
  List<GlobalKey> _postKeys = [];

  /// 已临时展开的被屏蔽楼层 pid（不硬删键位）。
  final Set<String> _expandedBlockedPids = {};

  /// 防止连点叠加滚动动画。
  bool _scrollAnimating = false;

  /// 楼级进度回写节流。
  DateTime? _lastFloorProgressAt;

  @override
  void dispose() {
    _scrollFabVisibility.dispose();
    super.dispose();
  }

  /// 记录阅读进度：写库 + 刷新历史列表（使列表卡片/历史页/资料计数实时更新）。
  /// readCount 只在本次进入详情页首帧 +1（isNewVisit 由 _hasRecordedInitialVisit 守卫）。
  void _recordProgress(PostListState state, {int? floorInPage}) {
    if (_pendingInitialNavigation) {
      return;
    }
    final settings = ref.read(settingsProvider);
    final auth = ref.read(authStateProvider);
    if (!shouldRecordReadingProgress(settings, auth)) {
      return;
    }
    // Prefer the caller-provided / last visible floor. Never fall back to
    // `posts.length` (that permanently wrote "page end" as fake progress).
    final resolvedFloor = floorInPage ?? _lastRecordedFloorInPage ?? 1;
    if (!shouldWriteReadingProgressUpdate(
      hasRecordedInitialVisit: _hasRecordedInitialVisit,
      lastRecordedPage: _lastRecordedPage,
      lastRecordedFloorInPage: _lastRecordedFloorInPage,
      currentPage: state.currentPage,
      currentFloorInPage: resolvedFloor,
    )) {
      return;
    }
    ref.read(readingHistoryServiceProvider).updateProgress(
          tid: widget.tid,
          page: state.currentPage,
          floorInPage: resolvedFloor,
          subject: state.threadSubject ?? '',
          author: state.posts.isNotEmpty ? state.posts.first.author : '',
          fid: state.threadFid ?? '',
          totalPages: state.totalPages,
          totalReplies: state.totalReplies,
          perPage: state.perPage,
          isNewVisit: !_hasRecordedInitialVisit,
        );
    _hasRecordedInitialVisit = true;
    _lastRecordedPage = state.currentPage;
    _lastRecordedFloorInPage = resolvedFloor;
    final record =
        ref.read(readingHistoryServiceProvider).getRecord(widget.tid);
    if (record != null) {
      ref.read(readingHistoryProvider.notifier).upsert(record);
    }
  }

  void _maybeRecordVisibleFloor(PostListState state) {
    final now = DateTime.now();
    if (_lastFloorProgressAt != null &&
        now.difference(_lastFloorProgressAt!) <
            const Duration(milliseconds: 400)) {
      return;
    }
    final index = ScrollFloorNavigator.findLeadingVisiblePostIndex(
      postKeys: _postKeys,
    );
    if (index == null) return;
    _lastFloorProgressAt = now;
    _recordProgress(state, floorInPage: index + 1);
  }

  Future<void> _consumeOpenScrollTarget(PostListState state) async {
    if (_manualPageChange || _openScrollConsumed) return;
    final target = state.openScrollTarget;
    if (target == null) return;

    _pendingInitialNavigation = true;
    if (_postKeys.length != state.posts.length) {
      setState(() {
        _postKeys = List.generate(state.posts.length, (_) => GlobalKey());
      });
    } else if (mounted) {
      setState(() {});
    }
    await WidgetsBinding.instance.endOfFrame;

    final ok = await _applyOpenScrollTarget(state, target);
    if (!mounted) return;

    if (ok) {
      _openScrollConsumed = true;
      // Clear the progress gate before notifying listeners (clearOpenScrollTarget).
      _pendingInitialNavigation = false;
      if (mounted) setState(() {});
      ref.read(postProvider(widget.tid).notifier).clearOpenScrollTarget();
      _maybeRecordVisibleFloor(state);
    } else {
      // 懒列表尚未构建目标楼：短暂等待后重试。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openScrollConsumed) return;
        unawaited(_consumeOpenScrollTarget(state));
      });
    }
  }

  Future<bool> _applyOpenScrollTarget(
    PostListState state,
    OpenScrollTarget target,
  ) async {
    switch (target) {
      case ScrollToPageTop():
        await _scrollToTopImpl();
        return true;
      case ScrollToPid(:final pid, :final highlight):
        if (highlight) {
          setState(() => _highlightPid = pid);
        }
        final index = state.posts.indexWhere((p) => p.pid == pid);
        if (index < 0) return true;
        _scheduleEnsurePostKeys(state.posts.length);
        await WidgetsBinding.instance.endOfFrame;
        return ScrollFloorNavigator.scrollToIndex(
          postKeys: _postKeys,
          index: index,
          alignment: 0.15,
        );
      case ScrollToFloor(:final absoluteFloor):
        final index = floorToPageIndex(
          absoluteFloor: absoluteFloor,
          page: state.currentPage,
          perPage: state.perPage,
          postCount: state.posts.length,
        );
        _scheduleEnsurePostKeys(state.posts.length);
        await WidgetsBinding.instance.endOfFrame;
        return ScrollFloorNavigator.scrollToIndex(
          postKeys: _postKeys,
          index: index,
          alignment: 0.15,
        );
    }
  }

  void _maybeShowLocateError(PostListState state) {
    final message = state.locateError;
    if (message == null || message.isEmpty) return;
    if (_shownLocateError == message) return;
    _shownLocateError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      S1SnackBar.show(context, message: message);
    });
  }

  void _onScrollMetricsChanged(S1ScrollMetrics metrics) {
    final fab = _scrollFabVisibility.value;
    final showTop = S1FabLayout.shouldShowScrollToTop(
      metrics: metrics,
      currentlyShowing: fab.showScrollToTop,
    );
    final showDown = S1FabLayout.shouldShowScrollDown(
      metrics: metrics,
      currentlyShowing: fab.showScrollDown,
    );
    final atBottom = S1FabLayout.isAtPageBottom(
      metrics: metrics,
      currentlyAtBottom: fab.atPageBottom,
    );
    if (showTop != fab.showScrollToTop ||
        showDown != fab.showScrollDown ||
        atBottom != fab.atPageBottom) {
      _scrollFabVisibility.value = _ScrollFabVisibility(
        showScrollToTop: showTop,
        showScrollDown: showDown,
        atPageBottom: atBottom,
      );
    }

    final data = ref.read(postProvider(widget.tid)).asData?.value;
    if (data != null) {
      _maybeRecordVisibleFloor(data);
    }
  }

  void _scrollToTop() {
    unawaited(_runScrollAction(_scrollToTopImpl));
  }

  void _scrollToBottom() {
    unawaited(_runScrollAction(_scrollToBottomImpl));
  }

  Future<void> _scrollToTopImpl() async {
    await _swipeKey.currentState?.scrollToTop();
  }

  Future<void> _scrollToBottomImpl() async {
    await _swipeKey.currentState?.scrollToBottom();
  }

  Future<void> _runScrollAction(Future<void> Function() action) async {
    if (_scrollAnimating) return;
    _scrollAnimating = true;
    try {
      await action();
    } finally {
      _scrollAnimating = false;
    }
  }

  /// 保证 [_postKeys] 长度与当前页楼层数一致（在帧末调用，避免 build 期间副作用）。
  void _scheduleEnsurePostKeys(int count) {
    if (_postKeys.length == count) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_postKeys.length == count) return;
      setState(() {
        _postKeys = List.generate(count, (_) => GlobalKey());
      });
    });
  }

  /// 单击「下一楼」：滚至下一楼靠上展示；已是末楼则滚到页底。
  void _scrollToNextFloor() {
    unawaited(
      _runScrollAction(
        () async {
          await ScrollFloorNavigator.scrollToNextFloor(
            postKeys: _postKeys,
            onAtLastFloor: () => unawaited(_scrollToBottomImpl()),
          );
        },
      ),
    );
  }

  Future<void> _goToPage(int page) async {
    _scrollFabVisibility.value = const _ScrollFabVisibility();
    setState(() {
      _manualPageChange = true;
      _openScrollConsumed = true;
      _highlightPid = null;
      _postKeys = [];
    });
    await ref.read(postProvider(widget.tid).notifier).goToPage(page);
    if (!mounted) return;
    context.replace(
      ThreadRouteCodec.encodePath(ThreadPage(widget.tid, page)),
    );
    final loaded = ref.read(postProvider(widget.tid)).asData?.value;
    if (loaded != null) {
      // Page changes land at top; keys rebuild after the next frame.
      _recordProgress(loaded, floorInPage: 1);
    }
  }

  bool _showsPollOnPage(PostListState state) =>
      state.currentPage == 1 && state.poll != null;

  int _detailItemCount(PostListState state) =>
      state.posts.length + (_showsPollOnPage(state) ? 1 : 0);

  Future<void> _openCompose(
    PostListState state, {
    Post? replyTo,
    int? displayFloor,
  }) async {
    if (!ref.read(authStateProvider).isLoggedIn) {
      await context.push('/login');
      return;
    }
    if (!state.allowReply) {
      S1SnackBar.show(context, message: '该主题已关闭回复');
      return;
    }

    String? draftId;
    if (replyTo != null) {
      draftId = ComposeDraftStore.put(
        replyTo,
        displayFloor: displayFloor ?? replyTo.floor,
      );
    }

    final query = StringBuffer(
      '/compose?tid=${widget.tid}&fid=${state.threadFid ?? ''}',
    );
    final subject = state.threadSubject?.trim();
    if (subject != null && subject.isNotEmpty) {
      query.write('&subject=${Uri.encodeQueryComponent(subject)}');
    }
    if (draftId != null) {
      query.write('&draftId=$draftId');
    }
    if (replyTo != null) {
      query.write('&reppost=${replyTo.pid}');
    }

    final result = await context.push<ReplySubmitResult>(query.toString());
    if (!mounted || result == null || !result.isSuccess) return;

    await _afterReplySubmitted(result, state);
  }

  Future<void> _openEdit(PostListState state, Post post) async {
    final auth = ref.read(authStateProvider);
    if (!auth.isLoggedIn || auth.user?.uid != post.authorId) return;
    final fid = state.threadFid;
    if (fid == null || fid.isEmpty) return;
    final result = await context.push<EditPostSubmitResult>(
      '/thread/${widget.tid}/post/${post.pid}/edit'
      '?fid=${Uri.encodeQueryComponent(fid)}'
      '&page=${state.currentPage}'
      '&first=${post.isFirst ? '1' : '0'}',
    );
    if (!mounted || result == null || !result.isSuccess) return;
    await ref.read(postProvider(widget.tid).notifier).refresh();
  }

  bool _canRatePost(Post post) {
    final auth = ref.read(authStateProvider);
    if (!auth.isLoggedIn) return false;
    final currentUid = auth.user?.uid;
    if (currentUid == null || currentUid.isEmpty) return false;
    return post.authorId != currentUid;
  }

  Future<void> _openRateDialog(Post post) async {
    if (!ref.read(authStateProvider).isLoggedIn) {
      await context.push('/login');
      return;
    }
    await showRateDialog(
      context,
      ref,
      tid: widget.tid,
      pid: post.pid,
    );
  }

  Future<void> _openReportDialog(Post post, PostListState state) async {
    if (!ref.read(authStateProvider).isLoggedIn) return;
    await showReportDialog(
      context,
      ref,
      tid: widget.tid,
      pid: post.pid,
      fid: state.threadFid,
      page: state.currentPage,
    );
  }

  Future<void> _afterReplySubmitted(
    ReplySubmitResult result,
    PostListState state,
  ) async {
    final notifier = ref.read(postProvider(widget.tid).notifier);
    setState(() {
      _manualPageChange = false;
      _openScrollConsumed = false;
    });
    if (result.pid != null && result.pid!.isNotEmpty) {
      await notifier.locatePid(result.pid!);
    } else {
      await notifier.goToPage(state.totalPages);
    }
  }

  Widget _buildDetailItem(
    BuildContext context,
    PostListState state,
    int index,
  ) {
    if (_showsPollOnPage(state) && index == 1) {
      return RepaintBoundary(
        key: ValueKey('poll-${widget.tid}'),
        child: PollCard(poll: state.poll!, tid: widget.tid),
      );
    }

    final postIndex = _showsPollOnPage(state) && index > 1 ? index - 1 : index;
    final post = state.posts[postIndex];
    final highlightPid = _highlightPid ??
        switch (state.openScrollTarget) {
          ScrollToPid(:final pid, :final highlight) when highlight => pid,
          _ => null,
        };

    final postKey = postIndex < _postKeys.length ? _postKeys[postIndex] : null;

    final floorOffset = (state.currentPage - 1) * state.perPage;
    final displayFloor = floorOffset + postIndex + 1;

    final isPostBlocked = post.authorId.isNotEmpty &&
        ref.watch(
          blacklistHasScopeProvider(
            (
              uid: post.authorId,
              scope: BlacklistRecord.scopePost,
            ),
          ),
        );
    final isExpanded = _expandedBlockedPids.contains(post.pid);

    if (isPostBlocked && !isExpanded) {
      return RepaintBoundary(
        key: ValueKey(post.pid),
        child: KeyedSubtree(
          key: postKey,
          child: _BlockedPostPlaceholder(
            author: post.author,
            onExpand: () {
              setState(() => _expandedBlockedPids.add(post.pid));
            },
          ),
        ),
      );
    }

    final currentUid = ref.watch(authStateProvider).user?.uid;
    final canAddToBlacklist =
        post.authorId.isNotEmpty && post.authorId != currentUid;
    final canEdit = post.authorId.isNotEmpty &&
        post.authorId == currentUid &&
        !(post.isFirst && state.threadSpecial != 0);

    return RepaintBoundary(
      key: ValueKey(post.pid),
      child: PostItem(
        key: postKey,
        post: post,
        displayFloor: displayFloor,
        tid: widget.tid,
        currentPage: state.currentPage,
        isHighlighted: highlightPid != null && post.pid == highlightPid,
        onFilterByAuthor: () {
          ref.read(postProvider(widget.tid).notifier).filterByAuthor(
                post.authorId,
                post.author,
              );
          _scrollToTop();
        },
        onReply: state.allowReply
            ? () => _openCompose(
                  state,
                  replyTo: post,
                  displayFloor: displayFloor,
                )
            : null,
        onShare: () => ref.read(postShareProvider.notifier).share(
              context: context,
              post: post,
              displayFloor: displayFloor,
              threadSubject: state.threadSubject,
            ),
        onEdit: canEdit ? () => _openEdit(state, post) : null,
        onRate: _canRatePost(post) ? () => _openRateDialog(post) : null,
        onAddToBlacklist:
            canAddToBlacklist ? () => _confirmAddToBlacklist(post) : null,
        onReport: ref.read(authStateProvider).isLoggedIn
            ? () => _openReportDialog(post, state)
            : null,
      ),
    );
  }

  Future<void> _confirmAddToBlacklist(Post post) async {
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '加入黑名单',
      content: '将「${post.author}」加入本地黑名单？\n'
          '默认屏蔽其主题列表与帖内楼层。',
      confirmLabel: '加入',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    ref.read(blacklistProvider.notifier).upsert(
          uid: post.authorId,
          username: post.author,
          scope: BlacklistRecord.defaultScopes,
        );
    if (!mounted) return;
    S1SnackBar.show(context, message: '已加入黑名单');
  }

  void _showFullTitle(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '完整标题',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBody() {
    return const Column(
      children: [
        LinearProgressIndicator(),
        Expanded(child: SizedBox()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PostListState>>(postProvider(widget.tid),
        (previous, next) {
      next.whenData((state) {
        _maybeShowLocateError(state);
        if (!_openScrollConsumed && state.openScrollTarget != null) {
          unawaited(_consumeOpenScrollTarget(state));
        } else if (!_pendingInitialNavigation) {
          _maybeRecordVisibleFloor(state);
        }
      });
    });

    final postsAsync = ref.watch(postProvider(widget.tid));
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );

    return S1DesktopScaffold(
      highlightedTab: 0,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: postsAsync.whenOrNull(
                data: (s) => s.threadSubject != null
                    ? GestureDetector(
                        onTap: () => _showFullTitle(context, s.threadSubject!),
                        child: Text(
                          s.threadSubject!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
              ) ??
              const Text('Thread'),
          actions: [
            FavoriteBookmarkButton(
              type: FavoriteType.thread,
              id: widget.tid,
            ),
            AppBarMoreMenu(
              onRefresh: () =>
                  ref.read(postProvider(widget.tid).notifier).refresh(),
              browserUrl: '${ApiConfig.baseUrl}/thread-${widget.tid}-1-1.html',
            ),
          ],
        ),
        // Keep the post list mounted while consuming OpenScrollTarget so
        // index-based scroll (pid / floor) can run against live GlobalKeys.
        // `_pendingInitialNavigation` only gates progress writeback.
        body: postsAsync.when(
          loading: _buildLoadingBody,
          error: (e, st) => S1ErrorView(
            error: e,
            onRetry: () =>
                ref.read(postProvider(widget.tid).notifier).refresh(),
            onLogin: () => context.push('/login'),
          ),
          data: (state) {
            _scheduleEnsurePostKeys(state.posts.length);
            final showPrimary = isLoggedIn && state.allowReply;
            final hasNextPage = state.currentPage < state.totalPages;
            final scheme = Theme.of(context).colorScheme;

            return Column(
              children: [
                if (state.isFiltering)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: scheme.primaryContainer,
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '只看「${state.filterAuthorName}」的帖子',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => ref
                              .read(postProvider(widget.tid).notifier)
                              .clearFilter(),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: scheme.onPrimaryContainer,
                          ),
                          label: Text(
                            '取消',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: S1ContentFabOverlay(
                    fab: ValueListenableBuilder<_ScrollFabVisibility>(
                      valueListenable: _scrollFabVisibility,
                      builder: (context, fab, _) {
                        final showScrollAdvance = fab.showScrollDown ||
                            (fab.atPageBottom && hasNextPage);
                        final advanceMode = fab.atPageBottom && hasNextPage
                            ? ScrollNavAdvanceMode.nextPage
                            : ScrollNavAdvanceMode.nextFloor;
                        return S1FabStack(
                          scrollNav: S1ScrollNavConfig(
                            showScrollToTop: fab.showScrollToTop,
                            showScrollAdvance: showScrollAdvance,
                            advanceMode: advanceMode,
                            onScrollToTop: _scrollToTop,
                            onScrollToNextFloor: _scrollToNextFloor,
                            onScrollToBottom: _scrollToBottom,
                            onGoToNextPage: hasNextPage
                                ? () => _goToPage(state.currentPage + 1)
                                : null,
                          ),
                          primary: showPrimary
                              ? S1FabItem(
                                  heroTag: 'replyDetail',
                                  icon: Icons.edit_outlined,
                                  tooltip: '回复',
                                  onPressed: () => _openCompose(state),
                                )
                              : null,
                        );
                      },
                    ),
                    child: S1SwipePagination(
                      key: _swipeKey,
                      currentPage: state.currentPage,
                      totalPages: state.totalPages,
                      onScrollMetricsChanged: _onScrollMetricsChanged,
                      onPageChanged: _goToPage,
                      pageBuilder: (context, scrollController) => Scrollbar(
                        controller: scrollController,
                        child: state.posts.isEmpty
                            ? const Center(child: Text('暂无回复'))
                            : ListView.builder(
                                controller: scrollController,
                                padding:
                                    S1FabLayout.threadDetailScrollBottomPadding,
                                itemCount: _detailItemCount(state),
                                itemBuilder: (context, index) =>
                                    _buildDetailItem(
                                  context,
                                  state,
                                  index,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                PaginationBar(
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  sheetSubtitle: state.threadSubject,
                  pageItemLabelBuilder: (page) {
                    final start = (page - 1) * state.perPage + 1;
                    final end = page * state.perPage;
                    return '第 $start - $end 楼';
                  },
                  onPageChanged: _goToPage,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 被屏蔽楼层的可展开占位行（保留列表键位）。
class _BlockedPostPlaceholder extends StatelessWidget {
  const _BlockedPostPlaceholder({
    required this.author,
    required this.onExpand,
  });

  final String author;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = author.isNotEmpty ? author : '未知用户';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: S1Shape.cardShape,
      child: InkWell(
        onTap: onExpand,
        borderRadius: S1Shape.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已屏蔽 · $name · 点按查看',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
