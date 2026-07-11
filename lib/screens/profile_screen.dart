import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_history_provider.dart';
import '../models/user.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/web_avatar.dart';
import '../utils/s1_snack_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人资料'),
        actions: [
          if (authState.isLoggedIn)
            AppBarMoreMenu(
              onRefresh: () =>
                  ref.read(authStateProvider.notifier).refreshProfile(),
              browserUrl: '${ApiConfig.baseUrl}/home.php?mod=space',
            ),
        ],
      ),
      body: const ProfileBody(),
    );
  }
}

class ProfileBody extends ConsumerStatefulWidget {
  const ProfileBody({super.key});

  @override
  ConsumerState<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<ProfileBody> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    // 显示加载中遮罩
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text('正在退出登录…'),
            ],
          ),
        ),
      ),
    ),);

    try {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        // 关闭加载遮罩
        Navigator.of(context).pop();
        S1SnackBar.show(context, message: '已退出登录');
      }
    } catch (e) {
      if (mounted) {
        // 关闭加载遮罩
        Navigator.of(context).pop();
        S1SnackBar.show(context, message: '退出失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final colorScheme = Theme.of(context).colorScheme;

    final avatarUrl = User.resolveAvatarUrl(user?.avatar, size: 'middle');
    final letter = (authState.username?.isNotEmpty == true)
        ? authState.username![0].toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _HeaderCard(
          avatarUrl: avatarUrl,
          letter: letter,
          username: authState.isLoggedIn
              ? (user?.username ?? authState.username ?? '')
              : null,
          groupTitle: user?.groupTitle,
          isLoggedIn: authState.isLoggedIn,
          onLogin: () => context.push('/login'),
        ),
        if (authState.isLoggedIn && user != null && user.uid.isNotEmpty) ...[
          const SizedBox(height: 16),
          _StatsCard(user: user),
          const SizedBox(height: 16),
          _S1StatsCard(user: user),
          const SizedBox(height: 16),
          _InfoCard(user: user),
        ],
        const SizedBox(height: 20),
        const _SystemGroupCard(),
        const SizedBox(height: 16),
        if (authState.isLoggedIn)
          _ActionTile(
            icon: Icons.logout,
            label: '退出登录',
            color: colorScheme.error,
            onTap: _isLoggingOut ? null : () => unawaited(_handleLogout()),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {

  const _HeaderCard({
    required this.avatarUrl,
    required this.letter,
    required this.username,
    required this.groupTitle,
    required this.isLoggedIn,
    required this.onLogin,
  });
  final String? avatarUrl;
  final String letter;
  final String? username;
  final String? groupTitle;
  final bool isLoggedIn;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            WebAvatar(url: avatarUrl, radius: 44, fallbackLetter: letter),
            const SizedBox(height: 16),
            if (isLoggedIn) ...[
              Text(
                username ?? '',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (groupTitle != null && groupTitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: S1Shape.full,
                  ),
                  child: Text(
                    groupTitle!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ] else ...[
              Text(
                '未登录',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '登录后查看更多信息',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('登录'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {

  const _StatsCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(label: '积分', value: user.credits),
            _VerticalDivider(),
            _StatItem(
              label: '帖子',
              value: user.posts,
              onTap: () => context.push(
                '/user-space/${user.uid}?username=${Uri.encodeComponent(user.username)}&self=1&tab=1',
              ),
            ),
            _VerticalDivider(),
            _StatItem(
              label: '主题',
              value: user.threads,
              onTap: () => context.push(
                '/user-space/${user.uid}?username=${Uri.encodeComponent(user.username)}&self=1',
              ),
            ),
            _VerticalDivider(),
            _StatItem(label: '好友', value: user.friends),
          ],
        ),
      ),
    );
  }
}

class _S1StatsCard extends StatelessWidget {

  const _S1StatsCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('🐟', style: textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    '${user.deadfish} 条',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '死鱼',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: Column(
                children: [
                  Text('🪿', style: textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    '${user.combat} 鹅',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '战斗力',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _StatItem extends StatelessWidget {

  const _StatItem({required this.label, required this.value, this.onTap});
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatCount(value),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: onTap != null ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: S1Shape.medium,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: content,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {

  const _InfoCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Column(
        children: [
          _InfoTile(label: 'UID', value: user.uid),
          if (user.regdate.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            _InfoTile(label: '注册时间', value: user.regdate),
          ],
          const Divider(height: 1, indent: 16, endIndent: 16),
          _InfoTile(label: '关注', value: '${user.following}'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _InfoTile(label: '粉丝', value: '${user.follower}'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _InfoTile(label: '在线时长', value: '${user.oltime} 小时'),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {

  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemGroupCard extends ConsumerWidget {
  const _SystemGroupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(readingHistoryProvider).length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.history, color: colorScheme.primary),
              title: const Text('阅读历史'),
              subtitle: Text(
                '浏览过的帖子记录',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (count > 0)
                    Text(
                      '$count',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
              onTap: () => context.push('/reading-history'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: colorScheme.primary),
              title: const Text('设置'),
              subtitle: Text(
                '主题、文字大小与显示',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: color.withValues(alpha: S1Alpha.subtle),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: S1Shape.large,
        ),
        onTap: onTap,
      ),
    );
  }
}
