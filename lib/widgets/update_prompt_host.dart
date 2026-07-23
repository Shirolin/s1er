import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/update_check_provider.dart';
import 'app_update_dialog.dart';

/// 消费 [updateCheckProvider] 的 pendingPrompt，在有 Navigator 的 context 下弹窗。
class UpdatePromptHost extends ConsumerStatefulWidget {
  const UpdatePromptHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends ConsumerState<UpdatePromptHost> {
  var _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateCheckState>(updateCheckProvider, (previous, next) {
      final prompt = next.pendingPrompt;
      if (prompt == null || _showing) return;
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _showing = false;
          return;
        }
        final notifier = ref.read(updateCheckProvider.notifier);
        try {
          await showAppUpdateDialog(
            context,
            evaluation: prompt,
            onPromptClosed: notifier.onPromptClosed,
          );
        } finally {
          if (mounted) {
            notifier.clearPendingPrompt();
          }
          _showing = false;
        }
      });
    });

    return widget.child;
  }
}
