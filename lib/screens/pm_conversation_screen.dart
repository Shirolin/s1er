import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../providers/pm_conversation_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pm_message_bubble.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/s1_swipe_pagination.dart';

class PmConversationScreen extends ConsumerStatefulWidget {
  const PmConversationScreen({
    super.key,
    required this.touid,
    this.partnerName,
  });

  final String touid;
  final String? partnerName;

  @override
  ConsumerState<PmConversationScreen> createState() =>
      _PmConversationScreenState();
}

class _PmConversationScreenState extends ConsumerState<PmConversationScreen> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();

  @override
  Widget build(BuildContext context) {
    final provider = pmConversationProvider(widget.touid);
    final async = ref.watch(provider);
    final title = widget.partnerName?.trim();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(title != null && title.isNotEmpty ? title : '私信会话'),
        actions: [
          AppBarMoreMenu(
            onRefresh: () => ref.read(provider.notifier).refresh(),
            browserUrl: '${ApiConfig.baseUrl}/home.php'
                '?mod=space&do=pm&subop=view&touid=${widget.touid}',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Column(
          children: [
            LinearProgressIndicator(),
            Expanded(child: SizedBox()),
          ],
        ),
        error: (error, stack) => S1ErrorView(
          error: error,
          onRetry: () => ref.read(provider.notifier).refresh(),
          onLogin: () => context.push('/login'),
        ),
        data: (state) {
          if (state.isBlocked) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('该用户已在私信范围中被屏蔽'),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: S1SwipePagination(
                  key: _swipeKey,
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  onPageChanged: (page) =>
                      ref.read(provider.notifier).goToPage(page),
                  pageBuilder: (context, scrollController) => RefreshIndicator(
                    onRefresh: () => ref.read(provider.notifier).refresh(),
                    child: state.items.isEmpty
                        ? ListView(
                            controller: scrollController,
                            children: const [
                              SizedBox(height: 48),
                              Center(child: Text('暂无会话内容')),
                            ],
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: state.items.length,
                            itemBuilder: (context, index) => PmMessageBubble(
                              key: ValueKey(
                                'pm_message_${state.items[index].id}_$index',
                              ),
                              message: state.items[index],
                            ),
                          ),
                  ),
                ),
              ),
              PaginationBar(
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onPageChanged: (page) =>
                    ref.read(provider.notifier).goToPage(page),
              ),
            ],
          );
        },
      ),
    );
  }
}
