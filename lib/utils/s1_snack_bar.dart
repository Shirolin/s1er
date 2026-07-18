import 'package:flutter/material.dart';

import '../theme/s1_haptics.dart';
import '../widgets/s1_fab_layout.dart';

/// Optional haptic paired with a SnackBar (avoid doubling a prior gesture).
enum S1SnackBarFeedback {
  none,
  success,
  error,
}

/// 全局 SnackBar：浮动在分页栏上方，不顶起内容区 FAB。
abstract class S1SnackBar {
  static const double _horizontalMargin = 16;

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    double? bottomClearance,
    S1SnackBarFeedback feedback = S1SnackBarFeedback.none,
  }) {
    switch (feedback) {
      case S1SnackBarFeedback.success:
        S1Haptics.light();
      case S1SnackBarFeedback.error:
        S1Haptics.heavy();
      case S1SnackBarFeedback.none:
        break;
    }

    final padding = MediaQuery.paddingOf(context);
    final clearance = bottomClearance ?? S1FabLayout.snackBarClearance;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          _horizontalMargin,
          0,
          _horizontalMargin,
          padding.bottom + clearance,
        ),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  /// Success without a preceding write-gesture haptic.
  static void success(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    double? bottomClearance,
  }) {
    show(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      bottomClearance: bottomClearance,
      feedback: S1SnackBarFeedback.success,
    );
  }

  /// Explicit error path (login fail, API error after gesture, etc.).
  static void error(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    double? bottomClearance,
  }) {
    show(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      bottomClearance: bottomClearance,
      feedback: S1SnackBarFeedback.error,
    );
  }
}
