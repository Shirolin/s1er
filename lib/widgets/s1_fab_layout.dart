import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 内容区 FAB 布局常量。
///
/// FAB 叠在 [Expanded] 内容区右下角，物理上位于分页栏上方，
/// 不使用 Scaffold.floatingActionButton，因此 SnackBar 不会顶起按钮。
abstract class S1FabLayout {
  static const double edgeMargin = 16;
  static const double stackGap = 12;
  static const double smallFabSize = 40;
  static const double regularFabSize = 56;

  /// 分页栏内容高度（不含 SafeArea），供 SnackBar 避让。
  static const double paginationBarHeight = S1BottomBarStyle.paginationBarHeight;
  static const double snackBarGap = 8;

  static double get snackBarClearance => paginationBarHeight + snackBarGap;

  static double stackHeight({
    bool showSecondary = false,
    bool showPrimary = false,
  }) {
    var height = 0.0;
    if (showSecondary) height += smallFabSize;
    if (showSecondary && showPrimary) height += stackGap;
    if (showPrimary) height += regularFabSize;
    return height;
  }

  /// ListView 底部留白，避免最后一条内容被 FAB 遮挡。
  static double contentBottomPadding({
    bool showSecondary = false,
    bool showPrimary = false,
  }) {
    final stack = stackHeight(
      showSecondary: showSecondary,
      showPrimary: showPrimary,
    );
    if (stack == 0) return edgeMargin;
    return edgeMargin + stack + edgeMargin;
  }
}

/// 单个 FAB 配置。
class S1FabItem {
  const S1FabItem({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.visible = true,
    this.small = false,
  });

  final Object heroTag;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool visible;
  final bool small;
}

/// 内容区右下角 FAB 纵列（次操作在上、主操作在下）。
class S1FabStack extends StatelessWidget {
  const S1FabStack({
    super.key,
    this.secondary,
    this.primary,
  });

  /// 次要操作（如返回顶部），使用 small FAB。
  final S1FabItem? secondary;
  /// 主操作（如回复 / 发帖）。
  final S1FabItem? primary;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (secondary != null && secondary!.visible) {
      children.add(_buildFab(secondary!));
    }
    if (primary != null && primary!.visible) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: S1FabLayout.stackGap));
      }
      children.add(_buildFab(primary!));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }

  Widget _buildFab(S1FabItem item) {
    if (item.small) {
      return FloatingActionButton.small(
        heroTag: item.heroTag,
        onPressed: item.onPressed,
        tooltip: item.tooltip,
        child: Icon(item.icon),
      );
    }
    return FloatingActionButton(
      heroTag: item.heroTag,
      onPressed: item.onPressed,
      tooltip: item.tooltip,
      child: Icon(item.icon),
    );
  }
}

/// 在可滚动内容区叠加 FAB，FAB 底部对齐内容区（分页栏之上）。
class S1ContentFabOverlay extends StatelessWidget {
  const S1ContentFabOverlay({
    super.key,
    required this.child,
    required this.fab,
    this.fabBottomPadding = S1FabLayout.edgeMargin,
  });

  final Widget child;
  final Widget fab;
  final double fabBottomPadding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          right: S1FabLayout.edgeMargin,
          bottom: fabBottomPadding,
          child: fab,
        ),
      ],
    );
  }
}
