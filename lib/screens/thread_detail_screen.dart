import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../models/post.dart';
import '../models/reply_submit_result.dart';
import '../providers/post_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_history_provider.dart';
import '../utils/compose_draft_store.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_item.dart';
import '../widgets/poll_card.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_fab_layout.dart';
import '../utils/s1_snack_bar.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {

  const ThreadDetailScreen({
    super.key,
    required this.tid,
    this.initialPage,
    this.targetPid,
  });
  final String tid;
  final int? initialPage;
  final String? targetPid;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _scrollController = ScrollController();
  final _targetKey = GlobalKey();
  String? _scrollOncePid;
  bool _showScrollToTop = false;
  bool _hasRecordedInitialVisit = false;
  bool _hasCheckedResume = false;
  String? _highlightPid;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.targetPid != null) {
        ref.read(postProvider(widget.tid).notifier).locatePid(widget.targetPid!);
      } else if (widget.initialPage != null && widget.initialPage! > 1) {
        ref.read(postProvider(widget.tid).notifier).goToPage(widget.initialPage!);
      }
    });
  }

  /// 记录阅读进度：写库 + 刷新历史列表（使列表卡片/历史页/资料计数实时更新）。
  /// readCount 只在本次进入详情页首帧 +1（isNewVisit 由 _hasRecordedInitialVisit 守卫）。
  void _recordProgress(PostListState state) {
    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn && (auth.user?.uid.isEmpty ?? true)) {
      return;
    }
    ref.read(readingHistoryServiceProvider).updateProgress(
          tid: widget.tid,
          page: state.currentPage,
          floorInPage: state.posts.length,
          subject: state.threadSubject ?? '',
          author: state.posts.isNotEmpty ? state.posts.first.author : '',
          fid: state.threadFid ?? '',
          totalPages: state.totalPages,
          totalReplies: state.totalReplies,
          perPage: state.perPage,
          isNewVisit: !_hasRecordedInitialVisit,
        );
    _hasRecordedInitialVisit = true;
    ref.invalidate(readingRecordProvider(widget.tid));
    // 刷新列表 StateNotifier：ThreadCard 进度条 / 历史页 / 资料计数据此实时更新。
    ref.read(readingHistoryProvider.notifier).refresh();
  }

  /// 无指定初始页时，若存在未读完的历史记录，提示续读。
  /// 必须在 [_recordProgress] 写库**之前**读取，否则读到的就是本次刚写入的当前页。
  void _checkResumeReading(PostListState state) {
    if (_hasCheckedResume) return;
    _hasCheckedResume = true;
    final record = ref.read(readingRecordProvider(widget.tid));
    if (record == null ||
        record.isFinished ||
        record.lastReadPage <= 1 ||
        record.lastReadPage == state.currentPage) {
      return;
    }
    final targetPage = record.lastReadPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      S1SnackBar.show(
        context,
        message: '上次阅读到第 $targetPage 页',
        actionLabel: '续读',
        onAction: () =>
            ref.read(postProvider(widget.tid).notifier).goToPage(targetPage),
        duration: const Duration(seconds: 5),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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

  Future<void> _afterReplySubmitted(
    ReplySubmitResult result,
    PostListState state,
  ) async {
    final notifier = ref.read(postProvider(widget.tid).notifier);
    if (result.pid != null && result.pid!.isNotEmpty) {
      setState(() => _highlightPid = result.pid);
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
      return PollCard(poll: state.poll!, tid: widget.tid);
    }

    final postIndex = _showsPollOnPage(state) && index > 1 ? index - 1 : index;
    final post = state.posts[postIndex];
    final highlightPid = widget.targetPid ?? _highlightPid;
    final isTarget = highlightPid != null && post.pid == highlightPid;

    if (isTarget && _scrollOncePid != post.pid) {
      _scrollOncePid = post.pid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _targetKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.15,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    }

    final floorOffset = (state.currentPage - 1) * state.perPage;
    final displayFloor = floorOffset + postIndex + 1;
    return PostItem(
      key: isTarget ? _targetKey : null,
      post: post,
      displayFloor: displayFloor,
      tid: widget.tid,
      rateLog: state.rateLogs[post.pid],
      isHighlighted: post.pid == highlightPid,
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
    );
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

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PostListState>>(postProvider(widget.tid),
        (previous, next) {
      next.whenData((state) {
        // 先按「上一次」记录判断是否提示续读，再写入本次进度。
        if (widget.initialPage == null && widget.targetPid == null) {
          _checkResumeReading(state);
        }
        _recordProgress(state);
      });
    });

    final postsAsync = ref.watch(postProvider(widget.tid));
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
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
          AppBarMoreMenu(
            onRefresh: () =>
                ref.read(postProvider(widget.tid).notifier).refresh(),
            browserUrl: '${ApiConfig.baseUrl}/thread-${widget.tid}-1-1.html',
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Column(
          children: [
            LinearProgressIndicator(),
            Expanded(child: SizedBox()),
          ],
        ),
        error: (e, st) => S1ErrorView(
          error: e,
          onRetry: () =>
              ref.read(postProvider(widget.tid).notifier).refresh(),
          onLogin: () => context.push('/login'),
        ),
        data: (state) {
          final fabPadding = S1FabLayout.contentBottomPadding(
            showSecondary: _showScrollToTop,
            showPrimary: isLoggedIn && state.allowReply,
          );
          final scheme = Theme.of(context).colorScheme;

          return Column(
          children: [
            if (state.isFiltering)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: scheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, size: 18, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '只看「${state.filterAuthorName}」的帖子',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(postProvider(widget.tid).notifier)
                          .clearFilter(),
                      icon: Icon(Icons.close, size: 18, color: scheme.onPrimaryContainer),
                      label: Text(
                        '取消',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: S1ContentFabOverlay(
                fab: S1FabStack(
                  secondary: S1FabItem(
                    heroTag: 'scrollToTopDetail',
                    icon: Icons.arrow_upward,
                    tooltip: '返回顶部',
                    onPressed: _scrollToTop,
                    visible: _showScrollToTop,
                    small: true,
                  ),
                  primary: isLoggedIn && state.allowReply
                      ? S1FabItem(
                          heroTag: 'replyDetail',
                          icon: Icons.edit_outlined,
                          tooltip: '回复',
                          onPressed: () => _openCompose(state),
                        )
                      : null,
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  child: state.posts.isEmpty
                      ? const Center(child: Text('暂无回复'))
                      : SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.only(bottom: fabPadding),
                          child: Column(
                            children: List.generate(
                              _detailItemCount(state),
                              (index) => _buildDetailItem(context, state, index),
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
              onPageChanged: (page) async {
                await ref.read(postProvider(widget.tid).notifier).goToPage(page);
                if (_scrollController.hasClients) {
                  await _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),
          ],
        );
        },
      ),
    );
  }
}
