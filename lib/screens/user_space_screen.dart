import '../widgets/s1_ink_well.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../models/thread_destination.dart';
import '../models/user_space_item.dart';
import '../providers/reading_history_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/blacklist_provider.dart';
import '../providers/user_space_provider.dart';
import '../models/blacklist_record.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/thread_navigation.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_list_boundary_footer.dart';
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/s1_content_width.dart';
import '../widgets/skeleton/s1_async_list_loading.dart';
import '../widgets/skeleton/list_row_skeleton.dart';
import '../widgets/skeleton/thread_card_skeleton.dart';
import '../widgets/s1_desktop_scaffold.dart';

class UserSpaceScreen extends ConsumerStatefulWidget {
  const UserSpaceScreen({
    super.key,
    required this.uid,
    this.username,
    this.initialTab = 0,
    this.isSelf = false,
  });
  final String uid;
  final String? username;
  final int initialTab;
  final bool isSelf;

  @override
  ConsumerState<UserSpaceScreen> createState() => _UserSpaceScreenState();
}

class _UserSpaceScreenState extends ConsumerState<UserSpaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Set<int> _visitedTabs;

  UserSpaceParams get _params => (widget.uid, widget.isSelf);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _visitedTabs = {_tabController.index};
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _visitedTabs.add(_tabController.index);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshVisited() async {
    final futures = <Future<void>>[];
    if (_visitedTabs.contains(0)) {
      futures.add(
        ref.read(userSpaceThreadsProvider(_params).notifier).refresh(),
      );
    }
    if (_visitedTabs.contains(1)) {
      futures.add(
        ref.read(userSpaceRepliesProvider(_params).notifier).refresh(),
      );
    }
    await Future.wait(futures);
  }

  int _browserPage() {
    final isReplyTab = _tabController.index == 1;
    if (isReplyTab) {
      return ref.watch(userSpaceRepliesProvider(_params)).asData?.value.page ??
          1;
    }
    return ref.watch(userSpaceThreadsProvider(_params)).asData?.value.page ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final pmBlocked = ref.watch(
      blacklistHasScopeProvider(
        (uid: widget.uid, scope: BlacklistRecord.scopePm),
      ),
    );
    final isSelf = widget.isSelf || auth.user?.uid == widget.uid;
    final title = widget.username != null && widget.username!.isNotEmpty
        ? '${widget.username} 的空间'
        : '用户空间';
    final isReplyTab = _tabController.index == 1;
    final browserUrl = ApiConfig.userSpaceBrowserUrl(
      uid: widget.uid,
      type: isReplyTab ? 'reply' : 'thread',
      page: _browserPage(),
    );

    return S1DesktopScaffold(
      highlightedTab: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(title),
          actions: [
            if (auth.isLoggedIn && !isSelf && !pmBlocked)
              IconButton(
                tooltip: '发私信',
                icon: const Icon(Icons.mail_outline),
                onPressed: () => context.push(
                  Uri(
                    path: '/pm/${widget.uid}',
                    queryParameters: {
                      if (widget.username?.trim().isNotEmpty == true)
                        'name': widget.username!.trim(),
                    },
                  ).toString(),
                ),
              ),
            AppBarMoreMenu(
              onRefresh: _refreshVisited,
              browserUrl: browserUrl,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '主题'),
              Tab(text: '回复'),
            ],
          ),
        ),
        body: S1ContentWidth(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (_visitedTabs.contains(0))
                _ThreadList(uid: widget.uid, isSelf: widget.isSelf)
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(1))
                _ReplyList(uid: widget.uid, isSelf: widget.isSelf)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({
    required this.uid,
    required this.isSelf,
  });
  final String uid;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (uid, isSelf);
    final async = ref.watch(userSpaceThreadsProvider(params));
    return async.when(
      loading: () => const S1AsyncListLoading(
        child: ThreadCardSkeletonList(),
      ),
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () =>
            ref.read(userSpaceThreadsProvider(params).notifier).refresh(),
        onLogin: () => context.push('/login'),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 48),
              Center(child: Text('暂无主题')),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: S1SwipePagination(
                currentPage: state.page,
                totalPages: state.totalPages,
                onPageChanged: (page) => ref
                    .read(userSpaceThreadsProvider(params).notifier)
                    .goToPage(page),
                pageBuilder: (context, scrollController) => ListView.builder(
                  controller: scrollController,
                  itemCount: state.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return S1ListBoundaryFooter(
                        kind: pagedBoundaryKind(
                          currentPage: state.page,
                          totalPages: state.totalPages,
                        ),
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey('uspace_thread_${state.items[index].tid}'),
                      child: _ThreadCard(item: state.items[index]),
                    );
                  },
                ),
              ),
            ),
            PaginationBar(
              currentPage: state.page,
              totalPages: state.totalPages,
              onPageChanged: (page) => ref
                  .read(userSpaceThreadsProvider(params).notifier)
                  .goToPage(page),
            ),
          ],
        );
      },
    );
  }
}

class _ReplyList extends ConsumerWidget {
  const _ReplyList({
    required this.uid,
    required this.isSelf,
  });
  final String uid;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (uid, isSelf);
    final async = ref.watch(userSpaceRepliesProvider(params));
    return async.when(
      loading: () => const S1AsyncListLoading(
        child: ListRowSkeletonList(),
      ),
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () =>
            ref.read(userSpaceRepliesProvider(params).notifier).refresh(),
        onLogin: () => context.push('/login'),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 48),
              Center(child: Text('暂无回复')),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: S1SwipePagination(
                currentPage: state.page,
                totalPages: state.totalPages,
                onPageChanged: (page) => ref
                    .read(userSpaceRepliesProvider(params).notifier)
                    .goToPage(page),
                pageBuilder: (context, scrollController) => ListView.builder(
                  controller: scrollController,
                  itemCount: state.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return S1ListBoundaryFooter(
                        kind: pagedBoundaryKind(
                          currentPage: state.page,
                          totalPages: state.totalPages,
                        ),
                      );
                    }
                    final item = state.items[index];
                    return KeyedSubtree(
                      key: ValueKey('uspace_reply_${item.tid}'),
                      child: _ReplyCard(item: item),
                    );
                  },
                ),
              ),
            ),
            PaginationBar(
              currentPage: state.page,
              totalPages: state.totalPages,
              onPageChanged: (page) => ref
                  .read(userSpaceRepliesProvider(params).notifier)
                  .goToPage(page),
            ),
          ],
        );
      },
    );
  }
}

class _ThreadCard extends ConsumerWidget {
  const _ThreadCard({required this.item});
  final UserSpaceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.2,
    );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: S1InkWell(
        onTap: () {
          final record = ref.read(readingRecordProvider(item.tid));
          context.push(
            buildThreadDetailPath(
              item.tid,
              record: record,
              liveTotalReplies: item.replies,
            ),
          );
        },
        borderRadius: S1Shape.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.forumName != null && item.forumName!.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: S1Shape.full,
                  ),
                  child: Text(
                    item.forumName!,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                item.subject,
                style: textTheme.titleSmall?.copyWith(height: 1.45),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 裸数字「45万 6435」在合并后的卡片按钮里没有单位，
              // 与帖子列表卡一致补上「浏览 / 回复」。
              Semantics(
                label: [
                  if (item.dateline > 0) formatTimeAgo(item.dateline),
                  '浏览 ${formatCount(item.views)}',
                  '回复 ${formatCount(item.replies)}',
                ].join('，'),
                excludeSemantics: true,
                child: Row(
                  children: [
                    if (item.dateline > 0) ...[
                      Text(formatTimeAgo(item.dateline), style: metaStyle),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      Icons.visibility_outlined,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatCount(item.views),
                      style: metaStyle,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatCount(item.replies),
                      style: metaStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.item});
  final UserSpaceItem item;

  /// 一张卡最多铺开的回复摘要条数，其余折叠为计数。
  static const maxVisibleEntries = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: S1InkWell(
        onTap: () {
          final firstPid =
              item.replyEntries.isEmpty ? null : item.replyEntries.first.pid;
          final destination = firstPid != null && firstPid.isNotEmpty
              ? ThreadPost(item.tid, firstPid)
              : ResumeThread(item.tid);
          context.push(ThreadRouteCodec.encodePath(destination));
        },
        borderRadius: S1Shape.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.subject,
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  height: 1.45,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 同一主题的多条回复合并在同一张卡里，避免标题/版块重复出现；
              // 一页里同一主题可能十几条，全部铺开会挤掉后续主题。
              for (final entry
                  in item.replyEntries.take(_ReplyCard.maxVisibleEntries))
                if (entry.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: scheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      entry.excerpt,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              if (item.replyEntries.length > _ReplyCard.maxVisibleEntries) ...[
                const SizedBox(height: 6),
                Text(
                  '还有 ${item.replyEntries.length - _ReplyCard.maxVisibleEntries} 条回复',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (item.forumName != null && item.forumName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.forumName!,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
