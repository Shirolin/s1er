import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/share_image_format.dart';
import '../../providers/settings_provider.dart';
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
                      'JPEG 体积小，PNG 无损但文件较大',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ShareImageFormat>(
                      segments: const [
                        ButtonSegment(
                          value: ShareImageFormat.jpeg,
                          label: Text('JPEG（体积小）'),
                        ),
                        ButtonSegment(
                          value: ShareImageFormat.png,
                          label: Text('PNG（无损）'),
                        ),
                      ],
                      selected: {settings.shareImageFormat},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
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
                      '更高清晰度意味着更大的文件；2x 适合多数场景',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 2, label: Text('标准 2x')),
                        ButtonSegment(value: 3, label: Text('高清 3x')),
                      ],
                      selected: {settings.sharePixelRatio},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
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
