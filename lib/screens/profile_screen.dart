import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/talker_provider.dart';
import '../services/talker.dart' as t;
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
        const SizedBox(height: 20),
        const _ReadingHistoryTile(),
        const SizedBox(height: 16),
        _ThemeSettingsCard(
          themeMode: settings.themeMode,
          themeColor: settings.themeColor,
          onThemeModeChanged: (v) =>
              ref.read(settingsProvider.notifier).setThemeMode(v),
          onThemeColorChanged: (v) =>
              ref.read(settingsProvider.notifier).setThemeColor(v),
        ),
        const SizedBox(height: 16),
        _DisplaySettingsCard(
          showImages: settings.showImages,
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
                    borderRadius: const BorderRadius.all(Radius.circular(9999)),
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
          formatCount(value),
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

String _getColorLabel(String key) {
  const labels = {
    'blue': '蓝',
    'purple': '紫',
    'sage': '绿',
    'indigo': '黛',
    'orange': '橙',
  };
  return labels[key] ?? key;
}

class _ThemeSettingsCard extends StatelessWidget {
  const _ThemeSettingsCard({
    required this.themeMode,
    required this.themeColor,
    required this.onThemeModeChanged,
    required this.onThemeColorChanged,
  });

  final String themeMode;
  final String themeColor;
  final ValueChanged<String> onThemeModeChanged;
  final ValueChanged<String> onThemeColorChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '主题设置',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '主题外观',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
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
                  const RoundedRectangleBorder(
                    borderRadius: S1Shape.medium,
                  ),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, indent: 0, endIndent: 0),
            const SizedBox(height: 20),
            Text(
              '主题配色',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: AppTheme.themeSeeds.entries.map((entry) {
                final key = entry.key;
                final color = entry.value;
                final isSelected = themeColor == key;
                return GestureDetector(
                  onTap: () => onThemeColorChanged(key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: colorScheme.primary,
                                  width: 3,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black87
                                    : Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getColorLabel(key),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplaySettingsCard extends StatelessWidget {
  const _DisplaySettingsCard({
    required this.showImages,
    required this.onShowImagesChanged,
  });

  final bool showImages;
  final ValueChanged<bool> onShowImagesChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '显示设置',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('显示图片'),
              secondary: const Icon(Icons.image_outlined),
              value: showImages,
              onChanged: onShowImagesChanged,
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.medium,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1, indent: 0, endIndent: 0),
            const _VersionTile(),
          ],
        ),
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
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkerScreen(talker: t.talker),
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
        shape: const RoundedRectangleBorder(
          borderRadius: S1Shape.medium,
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ReadingHistoryTile extends ConsumerWidget {
  const _ReadingHistoryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(readingHistoryProvider).length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest
          .withValues(alpha: S1Alpha.cardOverlay),
      child: ListTile(
        leading: Icon(Icons.history, color: colorScheme.primary),
        title: const Text('阅读历史'),
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
        shape: const RoundedRectangleBorder(borderRadius: S1Shape.large),
        onTap: () => context.push('/reading-history'),
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
  final VoidCallback onTap;

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
