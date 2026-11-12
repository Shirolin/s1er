import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/s1_haptics.dart';
import '../../utils/desktop_window.dart';
import 'settings_section_header.dart';

/// Desktop-only window behaviour. Hidden on Web and mobile.
class DesktopSettingsSection extends ConsumerWidget {
  const DesktopSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!S1DesktopWindow.isSupported) return const SizedBox.shrink();

    final closeToTray = ref.watch(
      settingsProvider.select((settings) => settings.closeToTray),
    );
    final showTrayIcon = ref.watch(
      settingsProvider.select((settings) => settings.showTrayIcon),
    );
    final scheme = Theme.of(context).colorScheme;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '桌面窗口'),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: Icon(
                Icons.notifications_active_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('在系统托盘显示图标'),
              subtitle: Text(
                '关闭后不创建托盘图标，关闭窗口即退出应用。',
                style: subtitleStyle,
              ),
              value: showTrayIcon,
              onChanged: (value) {
                S1Haptics.selection();
                ref.read(settingsProvider.notifier).setShowTrayIcon(value);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            SwitchListTile(
              secondary: Icon(
                Icons.minimize_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('关闭窗口时最小化到托盘'),
              subtitle: Text(
                showTrayIcon
                    ? '关闭窗口后应用继续在系统托盘运行。单击托盘图标可切换窗口显示；右键菜单可重新打开或彻底退出。'
                    : '需要先在系统托盘中显示图标。',
                style: subtitleStyle,
              ),
              value: closeToTray,
              onChanged: showTrayIcon
                  ? (value) {
                      S1Haptics.selection();
                      ref.read(settingsProvider.notifier).setCloseToTray(value);
                    }
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
