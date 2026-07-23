import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/list_density.dart';
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
    final threadListDensity = ref.watch(
      settingsProvider.select((settings) => settings.threadListDensity),
    );
    final postListDensity = ref.watch(
      settingsProvider.select((settings) => settings.postListDensity),
    );
    final hiddenCount = ref.watch(
      settingsProvider.select((settings) => settings.hiddenForums.length),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitleStyle = textTheme.bodySmall?.copyWith(
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
            ListTile(
              leading: Icon(
                Icons.visibility_off_outlined,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('已屏蔽版块'),
              subtitle: Text(
                hiddenCount == 0 ? '从首页隐藏不感兴趣的版块' : '已屏蔽 $hiddenCount 个版块',
                style: subtitleStyle,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(borderRadius: S1Shape.small),
              onTap: () => context.push('/hidden-forums'),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主题列表密度', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '仅影响版块主题列表。紧凑模式下同一屏可显示更多帖子。',
                    style: subtitleStyle,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ListDensity>(
                    segments: const [
                      ButtonSegment(
                        value: ListDensity.standard,
                        label: Text('标准'),
                      ),
                      ButtonSegment(
                        value: ListDensity.compact,
                        label: Text('紧凑'),
                      ),
                    ],
                    selected: {threadListDensity},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      S1Haptics.selection();
                      notifier.setThreadListDensity(selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('楼层密度', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '仅影响帖子详情楼层卡片外壳，正文排版不变。',
                    style: subtitleStyle,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ListDensity>(
                    segments: const [
                      ButtonSegment(
                        value: ListDensity.standard,
                        label: Text('标准'),
                      ),
                      ButtonSegment(
                        value: ListDensity.compact,
                        label: Text('紧凑'),
                      ),
                    ],
                    selected: {postListDensity},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      S1Haptics.selection();
                      notifier.setPostListDensity(selection.first);
                    },
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
