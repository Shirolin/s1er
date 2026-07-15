import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../models/dark_room_entry.dart';
import '../models/user.dart';
import '../providers/dark_room_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/web_avatar.dart';

class DarkRoomScreen extends ConsumerWidget {
  const DarkRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(darkRoomProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('小黑屋'),
        actions: [
          AppBarMoreMenu(
            onRefresh: () => ref.read(darkRoomProvider.notifier).refresh(),
            browserUrl: ApiConfig.darkRoomBrowserUrl(),
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
          onRetry: () => ref.read(darkRoomProvider.notifier).refresh(),
          onLogin: () => context.push('/login'),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return const _EmptyDarkRoom();
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(darkRoomProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: state.isLoadingMore
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonal(
                              onPressed: () => ref
                                  .read(darkRoomProvider.notifier)
                                  .loadMore(),
                              child: const Text('加载更多'),
                            ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DarkRoomCard(entry: state.items[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDarkRoom extends StatelessWidget {
  const _EmptyDarkRoom();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '暂无小黑屋记录',
          style: textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DarkRoomCard extends StatelessWidget {
  const _DarkRoomCard({required this.entry});

  final DarkRoomEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final letter =
        entry.username.isNotEmpty ? entry.username[0].toUpperCase() : '?';
    final avatarUrl = entry.uid.isEmpty
        ? null
        : User.resolveAvatarUrl(
            'https://avatar.stage1st.com/avatar.php?uid=${entry.uid}',
          );

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.uid.isEmpty
            ? null
            : () {
                final name = Uri.encodeComponent(entry.username);
                context.push('/user-space/${entry.uid}?username=$name');
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  WebAvatar(url: avatarUrl, radius: 20, fallbackLetter: letter),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.username.isEmpty
                              ? 'UID ${entry.uid}'
                              : entry.username,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entry.action.isNotEmpty)
                          Text(
                            entry.action,
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  entry.reason,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                [
                  if (entry.operatorName.isNotEmpty)
                    '操作人 ${entry.operatorName}',
                  if (entry.datelineRaw.isNotEmpty) '时间 ${entry.datelineRaw}',
                  if (entry.groupExpiryRaw.isNotEmpty)
                    '到期 ${entry.groupExpiryRaw}',
                ].join(' · '),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
