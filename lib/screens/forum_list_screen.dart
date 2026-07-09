import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/forum_list_provider.dart';
import '../providers/thread_list_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/thread_card.dart';

class ForumListScreen extends ConsumerStatefulWidget {

  const ForumListScreen({super.key, required this.fid});
  final String fid;

  @override
  ConsumerState<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends ConsumerState<ForumListScreen> {
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
        error: (e, st) {
          final scheme = Theme.of(context).colorScheme;
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (e is LoginRequiredException) ...[
                    Icon(Icons.lock_outline, size: 64, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('请先登录', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/login'),
                      icon: const Icon(Icons.login),
                      label: const Text('去登录'),
                    ),
                  ] else ...[
                    const Icon(Icons.error_outline, size: 56),
                    const SizedBox(height: 16),
                    Text(e.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(threadListProvider(widget.fid).notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        data: (state) => Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Scrollbar(
                    controller: _scrollController,
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(threadListProvider(widget.fid).notifier).refresh(),
                      child: state.threads.isEmpty
                          ? ListView(
                              controller: _scrollController,
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('暂无帖子')),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: state.threads.length,
                              itemBuilder: (context, index) =>
                                  ThreadCard(thread: state.threads[index]),
                            ),
                    ),
                  ),
                  if (_showScrollToTop)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        onPressed: _scrollToTop,
                        heroTag: 'scrollToTop',
                        child: const Icon(Icons.keyboard_arrow_up),
                      ),
                    ),
                ],
              ),
            ),
            PaginationBar(
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (page) async {
                await ref
                    .read(threadListProvider(widget.fid).notifier)
                    .goToPage(page);
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
        ),
      ),
    );
  }
}
