import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../services/font_import_service.dart';
import '../../theme/s1_haptics.dart';
import '../../utils/s1_snack_bar.dart';
import 'settings_section_header.dart';

class FontSettingsSection extends ConsumerStatefulWidget {
  const FontSettingsSection({super.key});

  @override
  ConsumerState<FontSettingsSection> createState() =>
      _FontSettingsSectionState();
}

class _FontSettingsSectionState extends ConsumerState<FontSettingsSection> {
  bool _isImporting = false;

  Future<void> _handleImportFont() async {
    S1Haptics.selection();
    const typeGroup = XTypeGroup(
      label: '字体文件 (.ttf, .otf)',
      extensions: ['ttf', 'otf'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      setState(() => _isImporting = true);

      final fileName = await FontImportService.importFont(file);
      ref.read(settingsProvider.notifier).setCustomFont(fileName);

      if (mounted) {
        S1SnackBar.success(context, message: '已成功导入字体：$fileName');
      }
    } on Object catch (e) {
      if (mounted) {
        S1SnackBar.error(context, message: '导入字体失败：${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _handleResetFont() {
    S1Haptics.selection();
    ref.read(settingsProvider.notifier).removeCustomFont();
    S1SnackBar.show(context, message: '已恢复默认字体');
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final customFontFileName = ref.watch(
      settingsProvider.select((s) => s.customFontFileName),
    );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: '字体设置'),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '当前字体：',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Expanded(
                  child: Text(
                    customFontFileName ?? '系统默认',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _isImporting ? null : _handleImportFont,
                  icon: _isImporting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(_isImporting ? '导入中…' : '导入字体文件…'),
                ),
                if (customFontFileName != null)
                  OutlinedButton.icon(
                    onPressed: _isImporting ? null : _handleResetFont,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('恢复默认'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '支持 .ttf 与 .otf 格式字体文件。导入后即刻全局生效。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
