import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/forum_list_provider.dart';
import '../providers/thread_list_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_bar_more_menu.dart';
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
                    const Text('请先登录', style: TextStyle(fontSize: 18)),
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
                      style: TextStyle(color: scheme.error),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(threadListProvider(widget.fid).notifier).refresh(),
                      child: const Text('重试'),
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
            _PaginationBar(fid: widget.fid, state: state),
          ],
        ),
      ),
    );
  }
}

class _PaginationBar extends ConsumerWidget {

  const _PaginationBar({required this.fid, required this.state});
  final String fid;
  final ThreadListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(threadListProvider(fid).notifier);
    final page = state.currentPage;
    final total = state.totalPages;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavButton(
              icon: Icons.first_page,
              onTap: page > 1 ? () => notifier.goToPage(1) : null,
              tooltip: '首页',
            ),
            _NavButton(
              icon: Icons.chevron_left,
              onTap: page > 1 ? () => notifier.goToPage(page - 1) : null,
              tooltip: '上一页',
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showPageJumpDialog(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$page / $total',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.unfold_more, size: 14, color: scheme.onPrimaryContainer),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _NavButton(
              icon: Icons.chevron_right,
              onTap: page < total ? () => notifier.goToPage(page + 1) : null,
              tooltip: '下一页',
            ),
            _NavButton(
              icon: Icons.last_page,
              onTap: page < total ? () => notifier.goToPage(total) : null,
              tooltip: '末页',
            ),
          ],
        ),
      ),
    );
  }

  void _showPageJumpDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳转到页码'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 - ${state.totalPages}',
          ),
          autofocus: true,
          onSubmitted: (_) {
            _performJump(ctx, controller, ref);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _performJump(ctx, controller, ref),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _performJump(BuildContext ctx, TextEditingController controller, WidgetRef ref) {
    final page = int.tryParse(controller.text);
    if (page != null && page >= 1 && page <= state.totalPages) {
      ref.read(threadListProvider(fid).notifier).goToPage(page);
      Navigator.pop(ctx);
    }
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 22,
            color: onTap != null ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
