import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../models/app_exceptions.dart';
import '../../providers/talker_provider.dart';
import '../../providers/update_check_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/s1_snack_bar.dart';
import '../app_update_dialog.dart';
import 'settings_section_header.dart';

class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionHeader(title: '关于'),
            SizedBox(height: 8),
            _VersionTile(),
            _CheckUpdateTile(),
          ],
        ),
      ),
    );
  }
}

class _VersionTile extends ConsumerStatefulWidget {
  const _VersionTile();

  @override
  ConsumerState<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends ConsumerState<_VersionTile> {
  int _tapCount = 0;

  void _onTap() {
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                TalkerScreen(talker: ref.read(talkerProvider)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(packageInfoProvider);
    final scheme = Theme.of(context).colorScheme;
    const itemShape = RoundedRectangleBorder(
      borderRadius: S1Shape.small,
    );

    return packageInfo.when(
      data: (info) => ListTile(
        leading: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
        title: const Text('版本'),
        subtitle: Text('${info.version} (${info.buildNumber})'),
        onTap: _onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: itemShape,
      ),
      loading: () => ListTile(
        leading: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
        title: const Text('版本'),
        subtitle: Text(
          '加载中…',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: itemShape,
      ),
      error: (_, __) => ListTile(
        leading: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
        title: const Text('版本'),
        subtitle: Text(
          '未知',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        onTap: _onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: itemShape,
      ),
    );
  }
}

class _CheckUpdateTile extends ConsumerStatefulWidget {
  const _CheckUpdateTile();

  @override
  ConsumerState<_CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends ConsumerState<_CheckUpdateTile> {
  Future<void> _onTap() async {
    final notifier = ref.read(updateCheckProvider.notifier);
    try {
      final evaluation = await notifier.checkManual();
      if (!mounted) return;
      if (evaluation.shouldShowDialog) {
        await showAppUpdateDialog(
          context,
          evaluation: evaluation,
          onPromptInteracted: notifier.markPromptInteracted,
          onIgnoreVersion: notifier.ignoreVersion,
        );
        return;
      }
      final message = evaluation.userMessage ?? '已是最新版本';
      S1SnackBar.show(context, message: message);
    } on UpdateCheckException catch (e) {
      if (!mounted) return;
      S1SnackBar.show(context, message: e.message);
    } on Object catch (e) {
      if (!mounted) return;
      S1SnackBar.show(context, message: '检查更新失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final checking = ref.watch(
      updateCheckProvider.select((s) => s.isChecking),
    );
    final scheme = Theme.of(context).colorScheme;
    const itemShape = RoundedRectangleBorder(
      borderRadius: S1Shape.small,
    );

    return ListTile(
      leading: Icon(Icons.system_update_alt, color: scheme.onSurfaceVariant),
      title: const Text('检查更新'),
      subtitle: Text(
        checking ? '正在检查…' : '从发布渠道获取最新版本',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      enabled: !checking,
      onTap: checking ? null : _onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: itemShape,
    );
  }
}
