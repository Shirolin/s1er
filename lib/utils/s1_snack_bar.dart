import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
  static const double _desktopMaxWidth = 400;

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = MediaQuery.paddingOf(context);
    final screenSize = MediaQuery.sizeOf(context);
    final clearance = bottomClearance ?? S1FabLayout.snackBarClearance;

    IconData iconData;
    Color backgroundColor;
    Color textColor;
    Color iconColor;

    switch (feedback) {
      case S1SnackBarFeedback.error:
        iconData = Icons.error_outline;
        backgroundColor = scheme.errorContainer;
        textColor = scheme.onErrorContainer;
        iconColor = scheme.onErrorContainer;
      case S1SnackBarFeedback.success:
        iconData = Icons.check_circle_outline;
        backgroundColor = scheme.inverseSurface;
        textColor = scheme.onInverseSurface;
        iconColor = scheme.primary;
      case S1SnackBarFeedback.none:
        iconData = Icons.info_outline;
        backgroundColor = scheme.inverseSurface;
        textColor = scheme.onInverseSurface;
        iconColor = scheme.onInverseSurface.withValues(alpha: S1Alpha.medium);
    }

    final isWideScreen = screenSize.width > 600;
    final double? width = isWideScreen ? _desktopMaxWidth : null;
    final EdgeInsets? margin = isWideScreen
        ? null
        : EdgeInsets.fromLTRB(
            _horizontalMargin,
            0,
            _horizontalMargin,
            padding.bottom + clearance,
          );

    final effectiveDuration = duration ??
        (actionLabel != null
            ? const Duration(seconds: 4)
            : const Duration(milliseconds: 2500));

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: S1Shape.medium,
        ),
        margin: margin,
        width: width,
        duration: effectiveDuration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: feedback == S1SnackBarFeedback.error
                    ? scheme.error
                    : scheme.inversePrimary,
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
    Duration? duration,
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
    Duration? duration,
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

  /// Safely show SnackBar only if BuildContext is still mounted.
  static void showIfMounted(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    double? bottomClearance,
    S1SnackBarFeedback feedback = S1SnackBarFeedback.none,
  }) {
    if (!context.mounted) return;
    show(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      bottomClearance: bottomClearance,
      feedback: feedback,
    );
  }

  /// Safely show success SnackBar only if BuildContext is still mounted.
  static void successIfMounted(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    double? bottomClearance,
  }) {
    if (!context.mounted) return;
    success(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      bottomClearance: bottomClearance,
    );
  }

  /// Safely show error SnackBar only if BuildContext is still mounted.
  static void errorIfMounted(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    double? bottomClearance,
  }) {
    if (!context.mounted) return;
    error(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      bottomClearance: bottomClearance,
    );
  }
}

