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

    return Card(
      elevation: 0,
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
            const SizedBox(height: 20),
            const SettingsSubsectionLabel(label: '主题配色'),
            const SizedBox(height: 16),
            ThemeColorPicker(
              selectedKey: settings.themeColor,
              onChanged: notifier.setThemeColor,
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
