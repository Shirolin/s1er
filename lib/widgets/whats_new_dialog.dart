import 'package:flutter/material.dart';

import '../models/whats_new_entry.dart';
import '../screens/whats_new_screen.dart';
import 'whats_new_entry_list.dart';

/// 升级后首次启动的 What's New 对话框。
Future<void> showWhatsNewDialog(
  BuildContext context, {
  required List<WhatsNewEntry> entries,
  required VoidCallback onDismissed,
  bool showViewAll = true,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Text(
          entries.length == 1 ? '新功能' : '更新说明',
          style: textTheme.headlineSmall,
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: WhatsNewEntryList(
              entries: entries,
              dense: true,
            ),
          ),
        ),
        actions: [
          if (showViewAll)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WhatsNewScreen(),
                  ),
                );
              },
              child: Text(
                '查看全部',
                style: textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
  onDismissed();
}
