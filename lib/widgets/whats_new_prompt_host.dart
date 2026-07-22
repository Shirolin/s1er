import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/update_check_provider.dart';
import '../providers/whats_new_provider.dart';
import 'whats_new_dialog.dart';

/// 消费 [whatsNewProvider] 的 pendingEntries；升级 Dialog 优先。
class WhatsNewPromptHost extends ConsumerStatefulWidget {
  const WhatsNewPromptHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WhatsNewPromptHost> createState() => _WhatsNewPromptHostState();
}

class _WhatsNewPromptHostState extends ConsumerState<WhatsNewPromptHost> {
  var _showing = false;

  void _scheduleTryShow() {
    if (_showing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tryShow());
    });
  }

  Future<void> _tryShow() async {
    if (!mounted || _showing) return;

    final update = ref.read(updateCheckProvider);
    if (update.pendingPrompt != null) return;

    final entries = ref.read(whatsNewProvider).pendingEntries;
    if (entries == null || entries.isEmpty) return;

    _showing = true;
    final notifier = ref.read(whatsNewProvider.notifier);
    try {
      await showWhatsNewDialog(
        context,
        entries: entries,
        onDismissed: () {
          unawaited(notifier.markSeenCurrent());
        },
      );
    } finally {
      if (mounted) {
        notifier.clearPendingEntries();
      }
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WhatsNewState>(whatsNewProvider, (previous, next) {
      if (next.pendingEntries != null) {
        _scheduleTryShow();
      }
    });
    ref.listen<UpdateCheckState>(updateCheckProvider, (previous, next) {
      final clearedPrompt =
          previous?.pendingPrompt != null && next.pendingPrompt == null;
      if (clearedPrompt) {
        _scheduleTryShow();
      }
    });

    return widget.child;
  }
}
