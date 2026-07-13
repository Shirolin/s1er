import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/forum_name_provider.dart';
import '../providers/thread_list_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/favorite_bookmark_button.dart';
import '../models/favorite_item.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_fab_layout.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/thread_card.dart';

class ForumListScreen extends ConsumerStatefulWidget {

  const ForumListScreen({super.key, required this.fid});
  final String fid;

  @override
  ConsumerState<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends ConsumerState<ForumListScreen> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();
  bool _showScrollToTop = false;

  void _onScrollMetricsChanged(S1ScrollMetrics metrics) {
    final show = S1FabLayout.shouldShowScrollToTop(
      metrics: metrics,
      currentlyShowing: _showScrollToTop,
    );
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(threadListProvider(widget.fid));
    final forum = ref.watch(forumNameProvider(widget.fid)) ??
        threadsAsync.asData?.value.forumName ??
        '';

    return Scaffold(
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
      body: threadsAsync.when(
        loading: () => const Column(
          children: [
            LinearProgressIndicator(),
            Expanded(child: SizedBox()),
          ],
        ),
        error: (e, st) => S1ErrorView(
          error: e,
          onRetry: () =>
              ref.read(threadListProvider(widget.fid).notifier).refresh(),
          onLogin: () => context.push('/login'),
        ),
        data: (state) {
          return Column(
          children: [
            Expanded(
              child: S1ContentFabOverlay(
                fab: S1FabStack(
                  scrollNav: S1ScrollNavConfig(
                    showScrollToTop: _showScrollToTop,
                    showScrollAdvance: false,
                    onScrollToTop: () =>
                        _swipeKey.currentState?.scrollToTop(),
                  ),
                ),
                child: S1SwipePagination(
                  key: _swipeKey,
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  onScrollMetricsChanged: _onScrollMetricsChanged,
                  onPageChanged: (page) => ref
                      .read(threadListProvider(widget.fid).notifier)
                      .goToPage(page),
                  pageBuilder: (context, scrollController) => Scrollbar(
                    controller: scrollController,
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(threadListProvider(widget.fid).notifier)
                          .refresh(),
                      child: state.threads.isEmpty
                          ? ListView(
                              controller: scrollController,
                              children: const [
                                SizedBox(height: 48),
                                Center(child: Text('暂无帖子')),
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
              onPageChanged: (page) => ref
                  .read(threadListProvider(widget.fid).notifier)
                  .goToPage(page),
            ),
          ],
        );
        },
      ),
    );
  }
}
