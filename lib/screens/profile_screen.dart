import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/user.dart';
import '../widgets/web_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider);
    final user = authState.user;
    final avatarUrl = User.resolveAvatarUrl(user?.avatar, size: 'middle');
    final letter = (authState.username?.isNotEmpty == true)
        ? authState.username![0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (authState.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(authStateProvider.notifier).refreshProfile(),
            ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(child: WebAvatar(url: avatarUrl, radius: 40, fallbackLetter: letter)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              authState.isLoggedIn
                  ? (user?.username ?? authState.username ?? '')
                  : '未登录',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (user != null && user.groupTitle != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.groupTitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (user != null && user.uid.isNotEmpty) ...[
            _buildStatsRow(context, user),
            const Divider(height: 32),
          ],
          _buildInfoTile(context, 'UID', user?.uid ?? '-'),
          _buildInfoTile(context, '积分', user?.credits.toString() ?? '-'),
          _buildInfoTile(context, '帖子数', user?.posts.toString() ?? '-'),
          _buildInfoTile(context, '主题数', user?.threads.toString() ?? '-'),
          const Divider(),
          SwitchListTile(
            title: const Text('深色模式'),
            value: settings.darkMode,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setDarkMode(v),
          ),
          SwitchListTile(
            title: const Text('显示图片'),
            value: settings.showImages,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setShowImages(v),
          ),
          const Divider(),
          if (authState.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () {
                ref.read(authStateProvider.notifier).logout();
                context.go('/');
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('登录'),
              onTap: () => context.push('/login'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, dynamic user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: '积分', value: '${user.credits}'),
          _StatItem(label: '帖子', value: '${user.posts}'),
          _StatItem(label: '主题', value: '${user.threads}'),
          _StatItem(label: '好友', value: '${user.friends}'),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value, style: TextStyle(color: Colors.grey[600])),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
