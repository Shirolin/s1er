import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'settings_section_header.dart';

class BrowsingSettingsSection extends ConsumerWidget {
  const BrowsingSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color:
          scheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '浏览行为'),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary:
                  Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
              title: const Text('显示图片'),
              subtitle: Text(
                '关闭后正文只显示图片占位，表情仍可见',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              value: settings.showImages,
              onChanged: notifier.setShowImages,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary:
                  Icon(Icons.history_outlined, color: scheme.onSurfaceVariant),
              title: const Text('记录阅读历史'),
              subtitle: Text(
                '关闭后不再写入新的阅读进度与阅读历史',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              value: settings.recordReadingHistory,
              onChanged: notifier.setRecordReadingHistory,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
              title: const Text('图片缓存'),
              subtitle: Text(
                '当前图片缓存由系统或浏览器管理，应用不提供离线图片缓存清理',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
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
