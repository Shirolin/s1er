import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/desktop_shortcut.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/s1_haptics.dart';
import '../../utils/s1_snack_bar.dart';
import 'app_icon_picker.dart';
import 'settings_section_header.dart';

/// Windows-only desktop icon section: window/taskbar icon and the managed
/// desktop shortcut. The executable's own file icon cannot be changed.
class DesktopIconSettingsSection extends ConsumerStatefulWidget {
  const DesktopIconSettingsSection({super.key});

  @override
  ConsumerState<DesktopIconSettingsSection> createState() =>
      _DesktopIconSettingsSectionState();
}

class _DesktopIconSettingsSectionState
    extends ConsumerState<DesktopIconSettingsSection> {
  bool _busy = false;

  Future<void> _createShortcut() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result =
        await ref.read(settingsProvider.notifier).createDesktopShortcut();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case DesktopShortcutResult.created:
        S1SnackBar.show(context, message: '已创建桌面快捷方式');
        ref.invalidate(desktopShortcutStatusProvider);
      case DesktopShortcutResult.nameConflict:
        S1SnackBar.show(
          context,
          message: '桌面已有同名 S1er.lnk，请先重命名或删除',
        );
      case DesktopShortcutResult.unsupported:
        break;
      case DesktopShortcutResult.failed:
        S1SnackBar.show(context, message: '创建桌面快捷方式失败');
      case DesktopShortcutResult.removed:
      case DesktopShortcutResult.notFound:
        break;
    }
  }

  Future<void> _removeShortcut() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result =
        await ref.read(settingsProvider.notifier).removeDesktopShortcut();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case DesktopShortcutResult.removed:
        S1SnackBar.show(context, message: '已删除桌面快捷方式');
        ref.invalidate(desktopShortcutStatusProvider);
      case DesktopShortcutResult.nameConflict:
      case DesktopShortcutResult.notFound:
        // No longer ours (or already gone); just resync the tile.
        ref.invalidate(desktopShortcutStatusProvider);
      case DesktopShortcutResult.failed:
        S1SnackBar.show(context, message: '删除桌面快捷方式失败');
      case DesktopShortcutResult.created:
      case DesktopShortcutResult.unsupported:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(desktopIconSupportedProvider)) {
      return const SizedBox.shrink();
    }

    final statusAsync = ref.watch(desktopShortcutStatusProvider);
    final status = statusAsync is AsyncData<DesktopShortcutStatus>
        ? statusAsync.value
        : statusAsync.hasError
            ? DesktopShortcutStatus.missing
            : null;
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
            const SettingsSectionHeader(title: '桌面图标'),
            const SizedBox(height: 8),
            Text(
              '用于窗口与任务栏图标；桌面快捷方式会跟随主题更新。'
              's1er.exe 本身的文件图标由系统读取嵌入资源，无法在应用内修改。',
              style: subtitleStyle,
            ),
            const SizedBox(height: 16),
            const AppIconPicker(desktop: true),
            const SizedBox(height: 8),
            Text(
              '选择「黑底」即可还原默认图标。',
              style: subtitleStyle,
            ),
            const Divider(height: 32),
            _ShortcutTile(
              status: status,
              busy: _busy,
              onCreate: _createShortcut,
              onRemove: _removeShortcut,
              subtitleStyle: subtitleStyle,
            ),
            const SizedBox(height: 4),
            Text(
              '已固定到任务栏的图标需取消固定后重新固定才会更新。',
              style: subtitleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.status,
    required this.busy,
    required this.onCreate,
    required this.onRemove,
    required this.subtitleStyle,
  });

  final DesktopShortcutStatus? status;
  final bool busy;
  final Future<void> Function() onCreate;
  final Future<void> Function() onRemove;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = status;

    final String title;
    final String subtitle;
    final Widget? trailing;
    switch (current) {
      case null:
        title = '桌面快捷方式';
        subtitle = '正在检查桌面快捷方式…';
        trailing = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DesktopShortcutStatus.missing:
        title = '创建桌面快捷方式';
        subtitle = '在桌面创建 S1er.lnk，图标跟随当前主题。';
        trailing = FilledButton.tonal(
          onPressed: busy
              ? null
              : () {
                  S1Haptics.selection();
                  onCreate();
                },
          child: const Text('创建'),
        );
      case DesktopShortcutStatus.ours:
        title = '桌面快捷方式';
        subtitle = '已创建。切换主题时快捷方式图标自动更新。';
        trailing = OutlinedButton(
          onPressed: busy
              ? null
              : () {
                  S1Haptics.selection();
                  onRemove();
                },
          child: const Text('删除'),
        );
      case DesktopShortcutStatus.foreign:
        title = '桌面快捷方式';
        subtitle = '桌面已有同名 S1er.lnk（指向其他程序），不会自动覆盖。';
        trailing = null;
    }

    return ListTile(
      leading: Icon(Icons.shortcut, color: scheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle, style: subtitleStyle),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: const RoundedRectangleBorder(
        borderRadius: S1Shape.small,
      ),
    );
  }
}
