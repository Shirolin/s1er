import 'package:flutter/material.dart';
import '../utils/window_size.dart';

/// 内容区域的宽度语义。
enum S1ContentWidthMode {
  /// 设置、资料、列表等常规页面。
  standard,

  /// 帖子正文等长文本阅读页面。
  reading,

  /// 登录、编辑等表单页面。
  form,
}

/// Constrains content width on wide screens per MD3 canonical layout.
///
/// - Compact / Medium (< 840dp): passes child through unchanged (full width).
/// - Expanded+ with [S1ContentWidthMode.standard]: 840dp (Expanded) / 1040dp (Large+).
/// - [S1ContentWidthMode.reading]: 720dp (comfortable thread body measure).
/// - [S1ContentWidthMode.form]: 720dp.
///
/// On wide screens the child is given a **tight** width and, when the parent
/// height is bounded, a tight height — so `Column` + `Expanded` (compose forms)
/// still layout correctly. Prefer this over `Center` + loose `ConstrainedBox`.
///
/// Usage:
/// ```dart
/// S1ContentWidth(child: ListView(...))
/// ```
class S1ContentWidth extends StatelessWidget {
  const S1ContentWidth({
    super.key,
    required this.child,
    this.mode = S1ContentWidthMode.standard,
  });

  /// The child widget to constrain.
  final Widget child;

  final S1ContentWidthMode mode;

  @override
  Widget build(BuildContext context) {
    if (!context.isExpandedOrAbove) {
      return child;
    }

    final maxWidth = switch (mode) {
      S1ContentWidthMode.form => S1Breakpoints.contentWidthForm,
      S1ContentWidthMode.reading => S1Breakpoints.contentWidthReading,
      S1ContentWidthMode.standard => context.windowSize == S1WindowSize.expanded
          ? S1Breakpoints.contentWidthExpanded
          : S1Breakpoints.contentWidthLarge,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = maxWidth.clamp(0.0, constraints.maxWidth).toDouble();
        final height =
            constraints.hasBoundedHeight ? constraints.maxHeight : null;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        );
      },
    );
  }
}
