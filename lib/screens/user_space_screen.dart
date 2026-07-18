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
import '../widgets/s1_swipe_pagination.dart';
import '../widgets/s1_content_width.dart';
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
    if (widget.initialTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(userSpaceProvider(_params).notifier).ensureRepliesLoaded();
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    _visitedTabs.add(index);
    setState(() {});
    if (index == 1) {
      ref.read(userSpaceProvider(_params).notifier).ensureRepliesLoaded();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userSpaceProvider(_params));
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
      page: isReplyTab
          ? async.asData?.value.replyPage ?? 1
          : async.asData?.value.threadPage ?? 1,
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
              onRefresh: () =>
                  ref.read(userSpaceProvider(_params).notifier).refresh(),
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
          child: async.when(
            loading: () => const Column(
              children: [
                LinearProgressIndicator(),
                Expanded(child: SizedBox()),
              ],
            ),
            error: (e, st) => S1ErrorView(
              error: e,
              onRetry: () =>
                  ref.read(userSpaceProvider(_params).notifier).refresh(),
              onLogin: () => context.push('/login'),
            ),
            data: (state) => TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                if (_visitedTabs.contains(0))
                  _ThreadList(
                    items: state.threads,
                    currentPage: state.threadPage,
                    totalPages: state.threadTotalPages,
                    uid: widget.uid,
                    isSelf: widget.isSelf,
                  )
                else
                  const SizedBox.shrink(),
                if (_visitedTabs.contains(1))
                  _ReplyList(
                    items: state.replies,
                    currentPage: state.replyPage,
                    totalPages: state.replyTotalPages,
                    uid: widget.uid,
                    isSelf: widget.isSelf,
                    repliesLoaded: state.repliesLoaded,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.uid,
    required this.isSelf,
  });
  final List<UserSpaceItem> items;
  final int currentPage;
  final int totalPages;
  final String uid;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
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
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) => ref
                .read(userSpaceProvider((uid, isSelf)).notifier)
                .goToThreadPage(page),
            pageBuilder: (context, scrollController) => ListView.builder(
              controller: scrollController,
              itemCount: items.length,
              itemBuilder: (context, index) => KeyedSubtree(
                key: ValueKey('uspace_thread_${items[index].tid}'),
                child: _ThreadCard(item: items[index]),
              ),
            ),
          ),
        ),
        PaginationBar(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref
              .read(userSpaceProvider((uid, isSelf)).notifier)
              .goToThreadPage(page),
        ),
      ],
    );
  }
}

class _ReplyList extends ConsumerWidget {
  const _ReplyList({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.uid,
    required this.isSelf,
    required this.repliesLoaded,
  });
  final List<UserSpaceItem> items;
  final int currentPage;
  final int totalPages;
  final String uid;
  final bool isSelf;
  final bool repliesLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!repliesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
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
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) => ref
                .read(userSpaceProvider((uid, isSelf)).notifier)
                .goToReplyPage(page),
            pageBuilder: (context, scrollController) => ListView.builder(
              controller: scrollController,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return KeyedSubtree(
                  key: ValueKey('uspace_reply_${item.pid ?? item.tid}'),
                  child: _ReplyCard(item: item),
                );
              },
            ),
          ),
        ),
        PaginationBar(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref
              .read(userSpaceProvider((uid, isSelf)).notifier)
              .goToReplyPage(page),
        ),
      ],
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: InkWell(
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
              Row(
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: S1Surface.card(scheme),
      shape: S1Shape.cardShape,
      child: InkWell(
        onTap: () {
          final destination = item.pid != null && item.pid!.isNotEmpty
              ? ThreadPost(item.tid, item.pid!)
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
              if (item.replyExcerpt != null &&
                  item.replyExcerpt!.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                    item.replyExcerpt!,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
