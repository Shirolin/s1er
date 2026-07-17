import 'package:flutter/material.dart';

import '../utils/window_size.dart';

enum S1DesktopSheetPresentation { dialog, sideSheet }

/// 在紧凑屏使用底部弹层、在桌面使用限宽对话框的辅助入口。
///
/// ## 关闭约定（MD3）
///
/// **标准高度 modal sheet / adaptive sheet（本 API）不放关闭按钮 chrome。**
/// 关闭依赖：
/// - 紧凑屏：`showDragHandle` 下拉、点 scrim、系统返回
/// - 桌面 dialog / side sheet：点 barrier、Escape / 返回
///
/// 需要显式关闭控件的情况（不要用本约定一刀切去掉）：
/// - [AlertDialog] / 确认框：用「取消 / 关闭」等 **actions**（非抽屉顶栏 X）
/// - **全屏** modal sheet：顶栏关闭 affordance
/// - 内容错误/空态且无其它主操作：内容区可放「关闭」等 CTA（如资料加载失败）
///
/// 禁止在 sheet 内容里再画一套自定义 drag handle（本 API 紧凑屏已提供）。
Future<T?> showS1AdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double desktopMaxWidth = 560,
  bool isScrollControlled = true,
  S1DesktopSheetPresentation desktopPresentation =
      S1DesktopSheetPresentation.dialog,

  /// When true with [S1DesktopSheetPresentation.sideSheet], the panel
  /// height shrinks to its child instead of filling the viewport.
  bool desktopSideSheetFitContent = false,
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
      pageBuilder: (dialogContext, _, __) {
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panel = Material(
                color: Theme.of(dialogContext).colorScheme.surfaceContainerLow,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: desktopMaxWidth,
                  height: desktopSideSheetFitContent ? null : double.infinity,
                  child: desktopSideSheetFitContent
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight,
                          ),
                          child: builder(dialogContext),
                        )
                      : builder(dialogContext),
                ),
              );

              return Align(
                alignment: desktopSideSheetFitContent
                    ? Alignment.topRight
                    : Alignment.centerRight,
                child: panel,
              );
            },
          ),
        );
      },
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
