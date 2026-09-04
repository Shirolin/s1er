import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/share_image_format.dart';
import '../../models/share_pixel_ratio.dart';
import '../../models/share_save_mode.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/s1_haptics.dart';
import '../../utils/compact_label.dart';
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
                child: SharePixelRatioSelector(
                  selected: settings.sharePixelRatio,
                  onChanged: notifier.setSharePixelRatio,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text('显示二维码', style: textTheme.titleSmall),
                subtitle: Text(
                  '部分平台会对带码图片限流',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                value: settings.shareShowQr,
                onChanged: (value) {
                  S1Haptics.selection();
                  notifier.setShareShowQr(value);
                },
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

class SharePixelRatioSelector extends StatelessWidget {
  const SharePixelRatioSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final double selected;
  final ValueChanged<double> onChanged;

  static const _compactBreakpoint = 360.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitleStyle = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final compact = MediaQuery.sizeOf(context).width < _compactBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('清晰度', style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          SharePixelRatio.subtitleFor(selected),
          style: subtitleStyle,
        ),
        const SizedBox(height: 12),
        if (compact)
          _SharePixelRatioDropdown(
            selected: selected,
            onChanged: onChanged,
          )
        else
          _SharePixelRatioSegments(
            selected: selected,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _SharePixelRatioSegmentLabel extends StatelessWidget {
  const _SharePixelRatioSegmentLabel({required this.option});

  final SharePixelRatioOption option;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactLabel.text(
          option.name,
          style: CompactLabel.style(
            context,
            base: textTheme.labelMedium,
          ),
        ),
        CompactLabel.text(
          SharePixelRatio.multiplierLabel(option.ratio),
          style: CompactLabel.style(
            context,
            base: textTheme.bodySmall,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SharePixelRatioSegments extends StatelessWidget {
  const _SharePixelRatioSegments({
    required this.selected,
    required this.onChanged,
  });

  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<double>(
        segments: [
          for (final option in SharePixelRatio.optionMeta)
            ButtonSegment<double>(
              value: option.ratio,
              label: _SharePixelRatioSegmentLabel(option: option),
            ),
        ],
        selected: {SharePixelRatio.normalize(selected)},
        showSelectedIcon: false,
        style: S1SegmentedButtonStyle.forScheme(scheme).merge(
          ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        ),
        onSelectionChanged: (selection) {
          S1Haptics.selection();
          onChanged(selection.first);
        },
      ),
    );
  }
}

class _SharePixelRatioDropdown extends StatelessWidget {
  const _SharePixelRatioDropdown({
    required this.selected,
    required this.onChanged,
  });

  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = SharePixelRatio.normalize(selected);

    return DropdownMenu<double>(
      key: ValueKey('share-pixel-ratio-$normalized'),
      initialSelection: normalized,
      label: const Text('清晰度'),
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: const InputDecorationTheme(filled: true),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(scheme.shadow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: S1Shape.small),
        ),
      ),
      dropdownMenuEntries: [
        for (final option in SharePixelRatio.optionMeta)
          DropdownMenuEntry<double>(
            value: option.ratio,
            label: SharePixelRatio.menuLabelFor(option.ratio),
            style: const ButtonStyle(
              maximumSize: WidgetStatePropertyAll(
                Size(double.infinity, double.infinity),
              ),
            ),
          ),
      ],
      onSelected: (value) {
        if (value == null) return;
        S1Haptics.selection();
        onChanged(value);
      },
    );
  }
}
