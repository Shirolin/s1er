import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/share_image_format.dart';
import '../../models/share_pixel_ratio.dart';
import '../../models/share_save_mode.dart';
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

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(title: '分享与导出'),
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
              if (isDesktop) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('保存方式', style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '控制 PC 桌面端点击保存分享图或大图时的文件处理方式。',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ShareSaveMode>(
                        segments: const [
                          ButtonSegment(
                            value: ShareSaveMode.autoDir,
                            label: Text('固定目录'),
                          ),
                          ButtonSegment(
                            value: ShareSaveMode.promptSaveAs,
                            label: Text('每次另存为'),
                          ),
                        ],
                        selected: {settings.shareSaveMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          S1Haptics.selection();
                          notifier.setShareSaveMode(selection.first);
                        },
                      ),
                      if (settings.shareSaveMode == ShareSaveMode.autoDir) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '保存目录',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (settings.customExportPath != null &&
                                            settings
                                                .customExportPath!.isNotEmpty)
                                        ? settings.customExportPath!
                                        : '默认（系统图片文件夹）',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                final selected = await getDirectoryPath(
                                  initialDirectory: settings.customExportPath,
                                );
                                if (selected != null && selected.isNotEmpty) {
                                  S1Haptics.selection();
                                  notifier.setCustomExportPath(selected);
                                }
                              },
                              child: const Text('更改目录'),
                            ),
                            if (settings.customExportPath != null &&
                                settings.customExportPath!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: '恢复系统默认',
                                onPressed: () {
                                  S1Haptics.selection();
                                  notifier.setCustomExportPath(null);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
