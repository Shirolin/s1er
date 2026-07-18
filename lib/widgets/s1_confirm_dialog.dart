import 'package:flutter/material.dart';

import '../theme/s1_haptics.dart';

/// MD3 确认弹窗：低强调 [TextButton]「取消」+ [FilledButton] 确认。
///
/// [destructive] 为 true 时确认按钮使用 [ColorScheme.error] / [ColorScheme.onError]。
Future<bool> showS1ConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (destructive) {
              S1Haptics.heavy();
            } else {
              S1Haptics.medium();
            }
            Navigator.of(ctx).pop(true);
          },
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
