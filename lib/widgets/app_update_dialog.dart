import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/update_check_provider.dart';
import '../utils/s1_snack_bar.dart';

typedef ExternalUrlLauncher = Future<bool> Function(
  Uri uri, {
  LaunchMode mode,
});

/// M3 升级提醒：强制更新仅「去更新」；可选更新「忽略此版」+「去更新」。
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required UpdateEvaluation evaluation,
  required VoidCallback onPromptInteracted,
  required void Function(String version) onIgnoreVersion,
  ExternalUrlLauncher? launchUrlFn,
}) async {
  final launch = launchUrlFn ??
      ((Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) =>
          launchUrl(uri, mode: mode));

  final force = evaluation.availability == UpdateAvailability.force;
  final notes = evaluation.manifest.notes.trim();
  final buffer = StringBuffer(
    force
        ? '当前版本过旧，请更新到 ${evaluation.manifest.latest} 以继续获得完整支持。'
        : '发现新版本 ${evaluation.manifest.latest}（当前 ${evaluation.localVersion}）。',
  );
  if (notes.isNotEmpty) {
    buffer.write('\n\n');
    buffer.write(notes);
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        title: Text(force ? '需要更新' : '发现新版本'),
        content: SingleChildScrollView(
          child: Text(buffer.toString()),
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () {
                onIgnoreVersion(evaluation.manifest.latest);
                Navigator.of(ctx).pop();
              },
              child: const Text('忽略此版'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.tryParse(evaluation.downloadUrl);
              if (uri == null) {
                if (context.mounted) {
                  S1SnackBar.show(context, message: '无法打开链接');
                }
                return;
              }
              try {
                final ok = await launch(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && context.mounted) {
                  S1SnackBar.show(context, message: '无法打开链接');
                }
              } on Object {
                if (context.mounted) {
                  S1SnackBar.show(context, message: '无法打开链接');
                }
              }
            },
            child: const Text('去更新'),
          ),
        ],
      );
    },
  );

  // 关闭 Dialog（scrim / 返回 / 按钮）均记入冷却；忽略此版额外写入 ignored。
  onPromptInteracted();
}
