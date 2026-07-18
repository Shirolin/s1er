import 'dart:async';

import 'package:flutter/services.dart';

/// Semantic haptic tokens for S1er interactions.
///
/// Gate with [enabled] (synced from settings). Unsupported platforms no-op.
abstract class S1Haptics {
  /// Master switch; updated by [SettingsNotifier].
  static bool enabled = true;

  /// Browse / switch / pick (high frequency).
  static void selection() {
    if (!enabled) return;
    unawaited(HapticFeedback.selectionClick());
  }

  /// Light confirm: copy, pull-to-refresh, non-destructive soft actions.
  static void light() {
    if (!enabled) return;
    unawaited(HapticFeedback.lightImpact());
  }

  /// Primary write / emphasized gesture.
  static void medium() {
    if (!enabled) return;
    unawaited(HapticFeedback.mediumImpact());
  }

  /// Destructive confirm or clear error path.
  static void heavy() {
    if (!enabled) return;
    unawaited(HapticFeedback.heavyImpact());
  }

  /// Fire [selection] then [callback] (null-safe).
  static VoidCallback? wrapTap(VoidCallback? callback) {
    if (callback == null) return null;
    return () {
      selection();
      callback();
    };
  }

  /// Fire [medium] then [callback] (null-safe).
  static VoidCallback? wrapLongPress(VoidCallback? callback) {
    if (callback == null) return null;
    return () {
      medium();
      callback();
    };
  }

  /// Pull-to-refresh / retry: [light] then [refresh].
  static Future<void> wrapRefresh(Future<void> Function() refresh) async {
    light();
    await refresh();
  }
}
