import 'package:flutter/material.dart';

import '../utils/window_size.dart';

enum S1DesktopSheetPresentation { dialog, sideSheet }

/// 在紧凑屏使用底部弹层、在桌面使用限宽对话框的辅助入口。
Future<T?> showS1AdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double desktopMaxWidth = 560,
  bool isScrollControlled = true,
  S1DesktopSheetPresentation desktopPresentation =
      S1DesktopSheetPresentation.dialog,
}) {
  if (!context.isExpandedOrAbove) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  if (desktopPresentation == S1DesktopSheetPresentation.sideSheet &&
      context.isLargeOrAbove) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Theme.of(dialogContext).colorScheme.surfaceContainerLow,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: desktopMaxWidth,
              height: double.infinity,
              child: builder(dialogContext),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: desktopMaxWidth),
        child: builder(dialogContext),
      ),
    ),
  );
}
