import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/share_image_format.dart';
import '../../models/share_pixel_ratio.dart';
import '../../providers/settings_provider.dart';
import '../../theme/s1_haptics.dart';
import '../s1_confirm_dialog.dart';
import 'settings_section_header.dart';

class ShareSettingsSection extends ConsumerWidget {
  const ShareSettingsSection({super.key});

  static const _advancedExportConfirmContent =
      '适用于单楼图片极多的长帖。导出会更慢、更耗内存，低端设备可能失败或卡顿；'
      '极罕见情况下拼接处可能出现细微接缝。不保证 100% 成功。';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(title: '分享'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('图片格式', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'WebP 默认体积小；JPEG 兼容性好；PNG 无损。',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ShareImageFormat>(
                      segments: const [
                        ButtonSegment(
                          value: ShareImageFormat.webp,
                          label: Text('WebP'),
                        ),
                        ButtonSegment(
                          value: ShareImageFormat.jpeg,
                          label: Text('JPEG'),
                        ),
                        ButtonSegment(
                          value: ShareImageFormat.png,
                          label: Text('PNG'),
                        ),
                      ],
                      selected: {settings.shareImageFormat},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        S1Haptics.selection();
                        notifier.setShareImageFormat(selection.first);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('清晰度', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '导出宽 ≈ 600×倍率；1.5x≈900px 默认均衡，2x≈1200px，3x 更清晰但更大',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(
                          value: SharePixelRatio.balanced,
                          label: Text('均衡 1.5x'),
                        ),
                        ButtonSegment(
                          value: SharePixelRatio.standard,
                          label: Text('标准 2x'),
                        ),
                        ButtonSegment(
                          value: SharePixelRatio.high,
                          label: Text('高清 3x'),
                        ),
                      ],
                      selected: {settings.sharePixelRatio},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        S1Haptics.selection();
                        notifier.setSharePixelRatio(selection.first);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text('高级导出', style: textTheme.titleSmall),
                subtitle: Text(
                  '单楼图片极多时使用楼内切块，放宽高度限制；更慢且可能失败',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                value: settings.shareAdvancedExport,
                onChanged: (value) async {
                  S1Haptics.selection();
                  if (value) {
                    final confirmed = await showS1ConfirmDialog(
                      context,
                      title: '开启高级导出',
                      content: _advancedExportConfirmContent,
                      confirmLabel: '开启',
                    );
                    if (!context.mounted || !confirmed) return;
                  }
                  notifier.setShareAdvancedExport(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
