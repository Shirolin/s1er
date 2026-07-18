import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/s1_haptics.dart';
import 'settings_section_header.dart';

class BrowsingSettingsSection extends ConsumerWidget {
  const BrowsingSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordReadingHistory = ref.watch(
      settingsProvider.select((settings) => settings.recordReadingHistory),
    );
    final hapticsEnabled = ref.watch(
      settingsProvider.select((settings) => settings.hapticsEnabled),
    );
    final notifier = ref.read(settingsProvider.notifier);
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
            const SettingsSectionHeader(title: '浏览行为'),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary:
                  Icon(Icons.history_outlined, color: scheme.onSurfaceVariant),
              title: const Text('记录阅读历史'),
              subtitle: Text(
                '关闭后不再写入新的阅读进度与阅读历史。已有记录不会自动删除。',
                style: subtitleStyle,
              ),
              value: recordReadingHistory,
              onChanged: (value) {
                S1Haptics.selection();
                notifier.setRecordReadingHistory(value);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            SwitchListTile(
              secondary: Icon(
                Icons.vibration_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('交互震动'),
              subtitle: Text(
                '按钮、列表与确认等操作提供触感反馈。关闭开关时仍会震动一次。仅移动端有体感。',
                style: subtitleStyle,
              ),
              value: hapticsEnabled,
              onChanged: (value) {
                if (value) {
                  notifier.setHapticsEnabled(true);
                  S1Haptics.selection();
                } else {
                  S1Haptics.selection();
                  notifier.setHapticsEnabled(false);
                }
              },
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
