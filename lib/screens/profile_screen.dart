import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/talker_provider.dart';
import '../models/user.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/web_avatar.dart';

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

class ProfileBody extends ConsumerWidget {
  const ProfileBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider);
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
        const SizedBox(height: 16),
        _SettingsCard(
          themeMode: settings.themeMode,
          showImages: settings.showImages,
          onThemeModeChanged: (v) =>
              ref.read(settingsProvider.notifier).setThemeMode(v),
          onShowImagesChanged: (v) =>
              ref.read(settingsProvider.notifier).setShowImages(v),
        ),
        const SizedBox(height: 16),
        if (authState.isLoggedIn)
          _ActionTile(
            icon: Icons.logout,
            label: '退出登录',
            color: colorScheme.error,
            onTap: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/');
            },
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            WebAvatar(url: avatarUrl, radius: 44, fallbackLetter: letter),
            const SizedBox(height: 12),
            if (isLoggedIn) ...[
              Text(
                username ?? '',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (groupTitle != null && groupTitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    groupTitle!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
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
              const SizedBox(height: 12),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(label: '积分', value: user.credits),
            _VerticalDivider(),
            _StatItem(label: '帖子', value: user.posts),
            _VerticalDivider(),
            _StatItem(label: '主题', value: user.threads),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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

  const _StatItem({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatNumber(value),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
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
  }

  String _formatNumber(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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

class _SettingsCard extends StatelessWidget {

  const _SettingsCard({
    required this.themeMode,
    required this.showImages,
    required this.onThemeModeChanged,
    required this.onShowImagesChanged,
  });
  final String themeMode;
  final bool showImages;
  final ValueChanged<String> onThemeModeChanged;
  final ValueChanged<bool> onShowImagesChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              '设置',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题外观',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'system',
                      label: Text('跟随系统'),
                      icon: Icon(Icons.brightness_auto, size: 18),
                    ),
                    ButtonSegment(
                      value: 'light',
                      label: Text('浅色'),
                      icon: Icon(Icons.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text('深色'),
                      icon: Icon(Icons.dark_mode, size: 18),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (v) => onThemeModeChanged(v.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return BorderSide.none;
                      }
                      return BorderSide(
                        color: colorScheme.outlineVariant,
                      );
                    }),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colorScheme.secondaryContainer;
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colorScheme.onSecondaryContainer;
                      }
                      return colorScheme.onSurfaceVariant;
                    }),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('显示图片'),
            secondary: const Icon(Icons.image_outlined),
            value: showImages,
            onChanged: onShowImagesChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const _VersionTile(),
        ],
      ),
    );
  }
}

class _VersionTile extends ConsumerStatefulWidget {
  const _VersionTile();

  @override
  ConsumerState<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends ConsumerState<_VersionTile> {
  int _tapCount = 0;

  void _onTap() {
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      final talker = ref.read(talkerProvider);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkerScreen(talker: talker),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(packageInfoProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return packageInfo.when(
      data: (info) => ListTile(
        title: Text(
          'Version',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text('${info.version}+${info.buildNumber}'),
        onTap: _onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
      ),
    );
  }
}
