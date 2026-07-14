import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_membership_provider.dart';
import '../providers/reading_history_provider.dart';
import '../models/user.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/web_avatar.dart';
import '../widgets/s1_confirm_dialog.dart';
import '../utils/s1_snack_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.externalUrlLauncher});

  final Future<bool> Function(Uri url)? externalUrlLauncher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('个人资料'),
        actions: [
          if (isLoggedIn)
            AppBarMoreMenu(
              onRefresh: () =>
                  ref.read(authStateProvider.notifier).refreshProfile(),
              browserUrl: '${ApiConfig.baseUrl}/home.php?mod=space',
            ),
        ],
      ),
      body: ProfileBody(externalUrlLauncher: externalUrlLauncher),
    );
  }
}

class ProfileBody extends ConsumerStatefulWidget {
  const ProfileBody({super.key, this.externalUrlLauncher});

  final Future<bool> Function(Uri url)? externalUrlLauncher;

  @override
  ConsumerState<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<ProfileBody> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureProfileLoaded());
  }

  Future<void> _ensureProfileLoaded() async {
    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    if (!auth.isLoggedIn) return;
    if (auth.user != null && auth.user!.uid.isNotEmpty) return;
    await ref.read(authStateProvider.notifier).refreshProfile();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showS1ConfirmDialog(
      context,
      title: '确认退出',
      content: '确定要退出登录吗？',
      confirmLabel: '退出登录',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    // 显示加载中遮罩
    unawaited(
      showDialog<void>(
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
      ),
    );

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

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final didLaunch = await (widget.externalUrlLauncher?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!didLaunch && mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
    } catch (error) {
      if (mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

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
        if (authState.isLoggedIn) ...[
          const _FavoritesEntryCard(),
          const SizedBox(height: 16),
        ],
        const _SystemGroupCard(),
        const SizedBox(height: 16),
        _ProjectSupportCard(
          onOpenUrl: (url) => unawaited(_openExternalUrl(url)),
        ),
        const SizedBox(height: 16),
        if (authState.isLoggedIn)
          _LogoutTile(
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
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(child: _StatItem(label: '积分', value: user.credits)),
              _VerticalDivider(),
              Expanded(
                child: _StatItem(
                  label: '帖子',
                  value: user.posts,
                  onTap: () => context.push(
                    '/user-space/${user.uid}?username=${Uri.encodeComponent(user.username)}&self=1&tab=1',
                  ),
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatItem(
                  label: '主题',
                  value: user.threads,
                  onTap: () => context.push(
                    '/user-space/${user.uid}?username=${Uri.encodeComponent(user.username)}&self=1',
                  ),
                ),
              ),
              _VerticalDivider(),
              Expanded(child: _StatItem(label: '好友', value: user.friends)),
            ],
          ),
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
      mainAxisAlignment: MainAxisAlignment.center,
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

    if (onTap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: content,
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: S1Shape.medium,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
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

/// 资料页列表行共用栅格：16 + 24 icon + 16 gap = 56 文字起始线。
abstract class _ProfileListMetrics {
  static const double hPadding = 16;
  static const double iconSize = 24;
  static const double gap = 16;
  static const double vPadding = 12;
}

class _FavoritesEntryCard extends ConsumerWidget {
  const _FavoritesEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      favoriteMembershipProvider.select((s) => s.keys.length),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: _ProfileTwoLineRow(
        icon: Icons.bookmarks_outlined,
        title: '我的收藏',
        subtitle: '收藏的帖子与版块',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0) ...[
              Badge(label: Text('$count')),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right,
              size: _ProfileListMetrics.iconSize,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: () => context.push('/favorites'),
      ),
    );
  }
}

class _SystemGroupCard extends ConsumerWidget {
  const _SystemGroupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(readingHistoryProvider.select((s) => s.records.length));
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileTwoLineRow(
            icon: Icons.history_outlined,
            title: '阅读历史',
            subtitle: '浏览过的帖子记录',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 0) ...[
                  Badge(label: Text('$count')),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right,
                  size: _ProfileListMetrics.iconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () => context.push('/reading-history'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _ProfileListMetrics.hPadding,
            ),
            child: Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(
                alpha: S1Alpha.half,
              ),
            ),
          ),
          _ProfileTwoLineRow(
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '主题、文字大小与显示',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _ProjectSupportCard extends StatelessWidget {
  const _ProjectSupportCard({required this.onOpenUrl});

  static const _afdianUrl = 'https://ifdian.net/a/shirolin';
  static const _koFiUrl = 'https://ko-fi.com/shirolin';
  static const _githubUrl = 'https://github.com/Shirolin/s1-app';

  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _ProfileListMetrics.hPadding,
          ),
          child: Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(
              alpha: S1Alpha.half,
            ),
          ),
        );

    Widget externalIcon() => Icon(
          Icons.open_in_new,
          size: _ProfileListMetrics.iconSize,
          color: colorScheme.onSurfaceVariant,
        );

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支持项目', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '如果 S1 Client 对你有帮助，欢迎支持开发或关注项目。',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _ProfileTwoLineRow(
            icon: Icons.favorite_outline,
            title: '爱发电',
            subtitle: '支持项目开发',
            trailing: externalIcon(),
            onTap: () => onOpenUrl(_afdianUrl),
          ),
          divider(),
          _ProfileTwoLineRow(
            icon: Icons.local_cafe_outlined,
            title: 'Ko-fi',
            subtitle: '请开发者喝杯咖啡',
            trailing: externalIcon(),
            onTap: () => onOpenUrl(_koFiUrl),
          ),
          divider(),
          _ProfileTwoLineRow(
            leading: Image.asset(
              'assets/branding/github_mark.png',
              key: const Key('github-mark'),
              width: _ProfileListMetrics.iconSize,
              height: _ProfileListMetrics.iconSize,
              color: colorScheme.primary,
              colorBlendMode: BlendMode.srcIn,
              excludeFromSemantics: true,
            ),
            title: 'GitHub',
            subtitle: '查看项目源代码（即将开源）',
            trailing: externalIcon(),
            onTap: () => onOpenUrl(_githubUrl),
          ),
        ],
      ),
    );
  }
}

class _ProfileTwoLineRow extends StatelessWidget {
  const _ProfileTwoLineRow({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
    this.trailing,
  }) : assert((icon == null) != (leading == null));

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chevron = Icon(
      Icons.chevron_right,
      size: _ProfileListMetrics.iconSize,
      color: colorScheme.onSurfaceVariant,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _ProfileListMetrics.hPadding,
            vertical: _ProfileListMetrics.vPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _ProfileListMetrics.iconSize,
                height: _ProfileListMetrics.iconSize,
                child: leading ??
                    Icon(
                      icon,
                      size: _ProfileListMetrics.iconSize,
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(width: _ProfileListMetrics.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _ProfileListMetrics.gap),
              trailing ??
                  SizedBox(
                    width: _ProfileListMetrics.iconSize,
                    height: _ProfileListMetrics.iconSize,
                    child: Center(child: chevron),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: S1Shape.medium,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _ProfileListMetrics.hPadding,
              vertical: _ProfileListMetrics.vPadding,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _ProfileListMetrics.iconSize,
                  height: _ProfileListMetrics.iconSize,
                  child: Icon(
                    Icons.logout,
                    size: _ProfileListMetrics.iconSize,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: _ProfileListMetrics.gap),
                Text(
                  '退出登录',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
