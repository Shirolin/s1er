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
    final isDynamicAvailable = ref.watch(dynamicColorAvailableProvider);
    final dynamicEnabled = settings.useDynamicColor && isDynamicAvailable;

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
            const SizedBox(height: 12),
            SwitchListTile(
              secondary: Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Material You 动态取色'),
              subtitle: Text(
                !isDynamicAvailable
                    ? '当前设备或平台不支持 Material You 动态取色，已回退到手动配色'
                    : (dynamicEnabled
                        ? '使用系统壁纸强调色（不支持时回退到下方配色）'
                        : '关闭时使用下方手动配色'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              value: dynamicEnabled,
              onChanged: isDynamicAvailable ? notifier.setUseDynamicColor : null,
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
                onChanged: dynamicEnabled ? null : notifier.setThemeColor,
              ),
            ),
            if (!dynamicEnabled) const _CustomColorDebugger(),
          ],
        ),
      ),
    );
  }
}

class _CustomColorDebugger extends ConsumerStatefulWidget {
  const _CustomColorDebugger();

  @override
  ConsumerState<_CustomColorDebugger> createState() => _CustomColorDebuggerState();
}

class _CustomColorDebuggerState extends ConsumerState<_CustomColorDebugger> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final themeColor = ref.read(settingsProvider).themeColor;
    final isPreset = const ['blue', 'purple', 'sage', 'indigo', 'orange'].contains(themeColor);
    _controller = TextEditingController(text: isPreset ? '' : themeColor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyColor(String val) {
    if (val.trim().isEmpty) {
      setState(() => _errorText = null);
      return;
    }
    final cleanHex = val.replaceAll('#', '').trim();
    if (cleanHex.length != 6 && cleanHex.length != 8) {
      setState(() => _errorText = '请输入 6 位或 8 位十六进制颜色，如 #2B2930');
      return;
    }
    try {
      int.parse(cleanHex, radix: 16);
      setState(() => _errorText = null);
      ref.read(settingsProvider.notifier).setThemeColor(val.trim());
    } catch (_) {
      setState(() => _errorText = '格式错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(settingsProvider.select((s) => s.themeColor), (_, next) {
      final isNextPreset = const ['blue', 'purple', 'sage', 'indigo', 'orange'].contains(next);
      if (isNextPreset) {
        _controller.text = '';
      } else {
        if (_controller.text != next) {
          _controller.text = next;
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: '自定义调试种子色 (Hex)',
                  hintText: '如 #2B2930 或 #141218',
                  errorText: _errorText,
                  prefixIcon: const Icon(Icons.colorize_outlined),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onFieldSubmitted: _applyColor,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => _applyColor(_controller.text),
              child: const Text('应用'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          secondary: Icon(Icons.bug_report_outlined, color: scheme.onSurfaceVariant),
          title: const Text('模拟系统动态取色校正'),
          subtitle: Text(
            '开启时，该种子色将强行通过 `isDynamic = true` 色阶校正管线（模拟真机壁纸取色后的容器色拉伸），让您能在 Web 端调试实际对比度效果。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          value: settings.simulateDynamic,
          onChanged: ref.read(settingsProvider.notifier).setSimulateDynamic,
          contentPadding: EdgeInsets.zero,
        ),
      ],
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
