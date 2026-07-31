import 'package:flutter/material.dart';

import '../utils/window_size.dart';
import 's1_adaptive_sheet_spec.dart';

export 's1_adaptive_sheet_content.dart';
export 's1_adaptive_sheet_spec.dart';

enum S1DesktopSheetPresentation { dialog, sideSheet }

/// ## 作者指南
///
/// 1. 新 sheet 先选 preset：[showS1ActionSheet] / [showS1FormSheet] /
///    [showS1ProfileSheet] / [showS1InfoSheet]
/// 2. 内容层使用 [S1AdaptiveSheetScaffold]、[S1AdaptiveSheetHeader]、
///    [S1AdaptiveActionTile]、[S1AdaptiveSheetFooter]；禁止自写 `isDesktop`
///    padding
/// 3. AppBar 锚点菜单仍用 [s1_menu.dart] 的 `s1MenuItem`，不与 modal sheet 混用
///
/// ## 关闭约定（MD3）
///
/// **标准高度 modal sheet / adaptive sheet（本 API）不放关闭按钮 chrome。**
/// 关闭依赖：
/// - 紧凑屏：`showDragHandle` 下拉、点 scrim、系统返回
/// - 桌面 dialog / side sheet：点 barrier、Escape / 返回
///
/// 需要显式关闭控件的情况：
/// - [AlertDialog] / 确认框：用 actions
/// - **全屏** modal sheet：顶栏关闭 affordance
/// - 内容错误/空态且无其它主操作：内容区可放「关闭」CTA
///
/// 禁止在 sheet 内容里再画一套自定义 drag handle（紧凑屏 API 已提供）。
Future<T?> showS1AdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double desktopMaxWidth = S1AdaptiveSheetSpec.infoWidth,
  bool isScrollControlled = true,
  S1DesktopSheetPresentation desktopPresentation =
      S1DesktopSheetPresentation.dialog,
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
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return Dialog(
        backgroundColor: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: Theme.of(dialogContext).dialogTheme.shape ??
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktopMaxWidth),
          child: builder(dialogContext),
        ),
      );
    },
  );
}

/// 操作菜单：桌面居中 Dialog，移动端 bottom sheet。
Future<T?> showS1ActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showS1AdaptiveSheet<T>(
    context: context,
    desktopMaxWidth: S1AdaptiveSheetSpec.actionMenuWidth,
    isScrollControlled: true,
    builder: builder,
  );
}

/// 表单 / 搜索 / 页码选择：桌面宽 Dialog，可滚动。
Future<T?> showS1FormSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? desktopMaxWidth,
}) {
  return showS1AdaptiveSheet<T>(
    context: context,
    desktopMaxWidth: desktopMaxWidth ?? S1AdaptiveSheetSpec.formWidth,
    isScrollControlled: true,
    builder: builder,
  );
}

/// 用户资料：Large+ 右侧 side sheet，否则 Dialog。
Future<T?> showS1ProfileSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showS1AdaptiveSheet<T>(
    context: context,
    desktopMaxWidth: S1AdaptiveSheetSpec.profileWidth,
    isScrollControlled: true,
    desktopPresentation: S1DesktopSheetPresentation.sideSheet,
    desktopSideSheetFitContent: true,
    builder: builder,
  );
}

/// 纯信息展示：桌面居中 Dialog。
Future<T?> showS1InfoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? desktopMaxWidth,
}) {
  return showS1AdaptiveSheet<T>(
    context: context,
    desktopMaxWidth: desktopMaxWidth ?? S1AdaptiveSheetSpec.infoWidth,
    isScrollControlled: true,
    builder: builder,
  );
}
