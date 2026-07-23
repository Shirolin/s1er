import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';

/// 脏状态下离开 Compose：继续编辑 / 保留并离开 / 放弃草稿。
enum S1DraftLeaveChoice {
  stay,
  keepAndLeave,
  discardAndLeave,
}

/// MD3 三选一离开框。关闭对话框（点 scrim）视为 [S1DraftLeaveChoice.stay]。
Future<S1DraftLeaveChoice> showS1DraftLeaveDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  final choice = await showDialog<S1DraftLeaveChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.up,
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(ctx).pop(S1DraftLeaveChoice.stay),
            child: const Text('继续编辑'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              S1Haptics.medium();
              Navigator.of(ctx).pop(S1DraftLeaveChoice.keepAndLeave);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
              ),
            ),
            child: const Text('保留草稿并离开'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () {
              S1Haptics.heavy();
              Navigator.of(ctx).pop(S1DraftLeaveChoice.discardAndLeave);
            },
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
            child: const Text('放弃草稿'),
          ),
        ),
      ],
    ),
  );
  return choice ?? S1DraftLeaveChoice.stay;
}

