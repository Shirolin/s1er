import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/share_image_format.dart';
import '../../models/share_pixel_ratio.dart';
import '../../providers/settings_provider.dart';
import '../../theme/s1_haptics.dart';
import 'settings_section_header.dart';

class ShareSettingsSection extends ConsumerWidget {
  const ShareSettingsSection({super.key});

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
            ],
          ),
        ),
      ),
    );
  }
}
