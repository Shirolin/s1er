import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../providers/post_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/post_item.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {

  const ThreadDetailScreen({super.key, required this.tid, this.initialPage});
  final String tid;
  final int? initialPage;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialPage != null && widget.initialPage! > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(postProvider(widget.tid).notifier).goToPage(widget.initialPage!);
      });
    }
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

  void _showFullTitle(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
    final postsAsync = ref.watch(postProvider(widget.tid));
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(
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
                    Text('Error: $e'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(postProvider(widget.tid).notifier).refresh(),
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
              child: Scrollbar(
                controller: _scrollController,
                child: state.posts.isEmpty
                    ? const Center(child: Text('No posts'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: state.posts.length,
                        itemBuilder: (context, index) {
                          final post = state.posts[index];
                          final floorOffset = (state.currentPage - 1) * 30;
                          return PostItem(
                            post: post,
                            displayFloor: floorOffset + index + 1,
                            tid: widget.tid,
                          );
                        },
                      ),
              ),
            ),
            _PostPaginationBar(tid: widget.tid, state: state),
          ],
        ),
      ),
      floatingActionButton: _ThreadFabGroup(
        showScrollToTop: _showScrollToTop,
        onScrollToTop: _scrollToTop,
        isLoggedIn: isLoggedIn,
        tid: widget.tid,
        fid: postsAsync.valueOrNull?.threadFid ?? '',
      ),
    );
  }
}

class _ThreadFabGroup extends StatelessWidget {
  const _ThreadFabGroup({
    required this.showScrollToTop,
    required this.onScrollToTop,
    required this.isLoggedIn,
    required this.tid,
    required this.fid,
  });

  final bool showScrollToTop;
  final VoidCallback onScrollToTop;
  final bool isLoggedIn;
  final String tid;
  final String fid;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showScrollToTop)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton.small(
              onPressed: onScrollToTop,
              heroTag: 'scrollToTopDetail',
              child: const Icon(Icons.arrow_upward),
            ),
          ),
        if (isLoggedIn)
          FloatingActionButton(
            onPressed: () => context.push('/compose?tid=$tid&fid=$fid'),
            child: const Icon(Icons.edit_outlined),
          ),
      ],
    );
  }
}

class _PostPaginationBar extends ConsumerWidget {

  const _PostPaginationBar({required this.tid, required this.state});
  final String tid;
  final PostListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(postProvider(tid).notifier);
    final page = state.currentPage;
    final total = state.totalPages;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
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
                  borderRadius: S1Shape.large,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$page / $total',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
          onSubmitted: (_) => _performJump(ctx, controller, ref),
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
      ref.read(postProvider(tid).notifier).goToPage(page);
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
        borderRadius: S1Shape.small,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 22,
            color: onTap != null ? scheme.onSurface : scheme.onSurface.withValues(alpha: S1Alpha.medium),
          ),
        ),
      ),
    );
  }
}
