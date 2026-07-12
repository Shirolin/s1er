import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/image_load_policy.dart';
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
            Opacity(
              opacity: settings.showImages ? 1 : 0.5,
              child: IgnorePointer(
                ignoring: !settings.showImages,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '图片加载方式',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '全屏查看不受此限制；关闭「显示图片」时此项无效',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ImageLoadPolicy>(
                        segments: const [
                          ButtonSegment(
                            value: ImageLoadPolicy.always,
                            label: Text('始终'),
                          ),
                          ButtonSegment(
                            value: ImageLoadPolicy.wifiOnly,
                            label: Text('仅 Wi-Fi'),
                          ),
                          ButtonSegment(
                            value: ImageLoadPolicy.manual,
                            label: Text('手动'),
                          ),
                        ],
                        selected: {settings.imageLoadPolicy},
                        onSelectionChanged: (selection) {
                          notifier.setImageLoadPolicy(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
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
                '离线图片缓存在「数据管理」中查看占用并清理',
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
