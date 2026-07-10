import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/forum_list_provider.dart';
import '../providers/thread_list_provider.dart';
import '../widgets/app_bar_more_menu.dart';
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

  void _onScrollOffsetChanged(double offset) {
    final show = offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  String _forumName() {
    final categories = ref.watch(forumListProvider).valueOrNull;
    if (categories == null) return '';
    for (final cat in categories) {
      if (cat.fid == widget.fid) return cat.name;
      for (final sub in cat.subforums) {
        if (sub.fid == widget.fid) return sub.name;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(threadListProvider(widget.fid));
    final forum = _forumName();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(forum.isNotEmpty ? forum : '版块 #${widget.fid}'),
        actions: [
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
          final fabPadding = S1FabLayout.contentBottomPadding(
            showSecondary: _showScrollToTop,
          );

          return Column(
          children: [
            Expanded(
              child: S1ContentFabOverlay(
                fab: S1FabStack(
                  secondary: S1FabItem(
                    heroTag: 'scrollToTopForum',
                    icon: Icons.arrow_upward,
                    tooltip: '返回顶部',
                    onPressed: () => _swipeKey.currentState?.scrollToTop(),
                    visible: _showScrollToTop,
                    small: true,
                  ),
                ),
                child: S1SwipePagination(
                  key: _swipeKey,
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  onScrollOffsetChanged: _onScrollOffsetChanged,
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
                              padding: EdgeInsets.only(bottom: fabPadding),
                              itemCount: state.threads.length,
                              itemBuilder: (context, index) =>
                                  ThreadCard(thread: state.threads[index]),
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
