import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/compact_label.dart';
import 'settings_section_header.dart';
import 'theme_color_picker.dart';

class ThemeSettingsSection extends ConsumerWidget {
  const ThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final dynamicEnabled = settings.useDynamicColor;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: scheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '主题设置'),
            const SizedBox(height: 16),
            const SettingsSubsectionLabel(label: '主题外观'),
            const SizedBox(height: 12),
            ThemeModeSelector(
              themeMode: settings.themeMode,
              onChanged: notifier.setThemeMode,
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SwitchListTile(
              secondary: Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Material You 动态取色'),
              subtitle: Text(
                dynamicEnabled
                    ? '使用系统壁纸强调色（不支持时回退到下方配色）'
                    : '关闭时使用下方手动配色',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              value: dynamicEnabled,
              onChanged: notifier.setUseDynamicColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.small,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 20),
            SettingsSubsectionLabel(
              label: dynamicEnabled ? '回退配色' : '主题配色',
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: dynamicEnabled ? 0.55 : 1,
              child: ThemeColorPicker(
                selectedKey: settings.themeColor,
                onChanged: notifier.setThemeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    super.key,
    required this.themeMode,
    required this.onChanged,
  });

  final String themeMode;
  final ValueChanged<String> onChanged;

  static const _modes = [
    ('system', '跟随系统', Icons.brightness_auto, '跟随系统'),
    ('light', '浅色', Icons.light_mode, '浅色模式'),
    ('dark', '深色', Icons.dark_mode, '深色模式'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 360;

    final segments = _modes.map((mode) {
      final (value, label, icon, tooltip) = mode;
      return ButtonSegment<String>(
        value: value,
        label: compact
            ? null
            : CompactLabel.text(
                label,
                style: CompactLabel.style(context),
              ),
        icon: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 18),
        ),
        tooltip: compact ? tooltip : null,
      );
    }).toList();

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: segments,
        selected: {themeMode},
        onSelectionChanged: (v) => onChanged(v.first),
        showSelectedIcon: false,
        style: S1SegmentedButtonStyle.forScheme(scheme).merge(
          ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
