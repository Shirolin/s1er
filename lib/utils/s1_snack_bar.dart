import 'package:flutter/material.dart';

import '../widgets/s1_fab_layout.dart';

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
  }) {
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
}
