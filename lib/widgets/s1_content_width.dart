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
/// - Expanded (840–1199dp): centers child within a max width of 840dp.
/// - Large+ (>= 1200dp): centers child within a max width of 1040dp.
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
      S1ContentWidthMode.reading => S1Breakpoints.contentWidthExpanded,
      S1ContentWidthMode.standard => context.windowSize == S1WindowSize.expanded
          ? S1Breakpoints.contentWidthExpanded
          : S1Breakpoints.contentWidthLarge,
    };

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
