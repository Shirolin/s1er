import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../models/friend_summary.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_list_provider.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/s1_error_view.dart';
import '../widgets/web_avatar.dart';
import '../widgets/s1_desktop_scaffold.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendListProvider);
    final uid = ref.watch(authStateProvider.select((a) => a.user?.uid));
    final browserUrl = uid != null && uid.isNotEmpty
        ? ApiConfig.friendsBrowserUrl(uid)
        : '${ApiConfig.baseUrl}/home.php?mod=space&do=friend&view=me&mobile=2';

    return S1DesktopScaffold(
      highlightedTab: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('我的好友'),
          actions: [
            AppBarMoreMenu(
              onRefresh: () => ref.read(friendListProvider.notifier).refresh(),
              browserUrl: browserUrl,
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
            onRetry: () => ref.read(friendListProvider.notifier).refresh(),
            onLogin: () => context.push('/login'),
          ),
          data: (result) {
            if (result.items.isEmpty) {
              return const _EmptyFriends();
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(friendListProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: result.items.length,
                separatorBuilder: (ctx, _) => Divider(
                  height: 1,
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  return _FriendTile(friend: result.items[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无好友',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});

  final FriendSummary friend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final letter =
        friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: WebAvatar(
        url: friend.avatarUrl,
        radius: 20,
        fallbackLetter: letter,
      ),
      title: Text(
        friend.username.isEmpty ? 'UID ${friend.uid}' : friend.username,
      ),
      subtitle: Text(
        'UID ${friend.uid}',
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      onTap: () {
        final name = Uri.encodeComponent(friend.username);
        context.push('/user-space/${friend.uid}?username=$name');
      },
    );
  }
}
