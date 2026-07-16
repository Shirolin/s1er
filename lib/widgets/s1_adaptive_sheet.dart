import 'package:flutter/material.dart';

import '../utils/window_size.dart';

/// 在紧凑屏使用底部弹层、在桌面使用限宽对话框的辅助入口。
Future<T?> showS1AdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double desktopMaxWidth = 560,
  bool isScrollControlled = true,
}) {
  if (!context.isExpandedOrAbove) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: isScrollControlled,
      builder: builder,
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
