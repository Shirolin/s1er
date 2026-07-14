import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/notice_item.dart';
import '../models/thread_destination.dart';
import '../providers/messages_segment_provider.dart';
import '../providers/notice_list_provider.dart';
import '../providers/pm_list_provider.dart';
import '../theme/app_theme.dart';
import '../utils/thread_navigation.dart';
import '../widgets/notice_list_tile.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pm_list_tile.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_swipe_pagination.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  int _segment = 0;
  final _noticeSwipeKey = GlobalKey<S1SwipePaginationState>();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('我的消息')),
              ButtonSegment(value: 1, label: Text('我的提醒')),
            ],
            selected: {_segment},
            onSelectionChanged: (value) {
              final next = value.first;
              setState(() => _segment = next);
              ref.read(messagesSegmentProvider.notifier).select(next);
            },
            style: S1SegmentedButtonStyle.forScheme(scheme),
          ),
        ),
        Expanded(
          child: _segment == 0
              ? _PmListBody()
              : _NoticeListBody(swipeKey: _noticeSwipeKey),
        ),
      ],
    );
  }
}

class _PmListBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pmListProvider);

    return async.when(
      loading: () => const Column(
        children: [
          LinearProgressIndicator(),
          Expanded(child: SizedBox()),
        ],
      ),
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () => ref.read(pmListProvider.notifier).refresh(),
        onLogin: () => context.push('/login'),
      ),
      data: (state) => RefreshIndicator(
        onRefresh: () => ref.read(pmListProvider.notifier).refresh(),
        child: state.items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 48),
                  Center(child: Text('暂无私信')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return KeyedSubtree(
                    key: ValueKey('pm_${item.touid}'),
                    child: PmListTile(
                      item: item,
                      onTap: () => context.push(
                        Uri(
                          path: '/pm/${item.touid}',
                          queryParameters: {'name': item.partnerName},
                        ).toString(),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NoticeListBody extends ConsumerWidget {
  const _NoticeListBody({required this.swipeKey});

  final GlobalKey<S1SwipePaginationState> swipeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(noticeListProvider);

    return async.when(
      loading: () => const Column(
        children: [
          LinearProgressIndicator(),
          Expanded(child: SizedBox()),
        ],
      ),
      error: (e, st) => S1ErrorView(
        error: e,
        onRetry: () => ref.read(noticeListProvider.notifier).refresh(),
        onLogin: () => context.push('/login'),
      ),
      data: (state) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<NoticeFeed>(
              segments: const [
                ButtonSegment(
                  value: NoticeFeed.mypost,
                  label: Text('帖子提醒'),
                ),
                ButtonSegment(
                  value: NoticeFeed.system,
                  label: Text('系统通知'),
                ),
              ],
              selected: {state.feed},
              onSelectionChanged: (value) {
                final feed = value.first;
                ref.read(noticeFeedSelectionProvider.notifier).select(feed);
                ref.read(noticeListProvider.notifier).selectFeed(feed);
              },
              style: S1SegmentedButtonStyle.forScheme(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          Expanded(
            child: S1SwipePagination(
              key: swipeKey,
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (page) =>
                  ref.read(noticeListProvider.notifier).goToPage(page),
              pageBuilder: (context, scrollController) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(noticeListProvider.notifier).refresh(),
                child: state.items.isEmpty
                    ? ListView(
                        controller: scrollController,
                        children: const [
                          SizedBox(height: 48),
                          Center(child: Text('暂无提醒')),
                        ],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return KeyedSubtree(
                            key: ValueKey('notice_${item.id}'),
                            child: NoticeListTile(
                              item: item,
                              onTap: () {
                                if (!item.canNavigate) return;
                                final pid = item.pid;
                                final destination =
                                    pid != null && pid.isNotEmpty
                                        ? ThreadPost(item.tid, pid)
                                        : ResumeThread(item.tid);
                                context.push(
                                  ThreadRouteCodec.encodePath(destination),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          if (state.totalPages > 1)
            PaginationBar(
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (page) =>
                  ref.read(noticeListProvider.notifier).goToPage(page),
            ),
        ],
      ),
    );
  }
}
