import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 可滚动区域的偏移与视口尺寸，供「返回顶部 / 下一楼」等 FAB 判定使用。
class S1ScrollMetrics {
  const S1ScrollMetrics({
    required this.offset,
    required this.viewportDimension,
    this.maxScrollExtent = 0,
  });

  final double offset;
  final double viewportDimension;
  final double maxScrollExtent;
}

/// 内容区 FAB 布局常量。
///
/// FAB 叠在 [Expanded] 内容区右下角，物理上位于分页栏上方，
/// 不使用 Scaffold.floatingActionButton，因此 SnackBar 不会顶起按钮。
abstract class S1FabLayout {
  /// 滚动超过视口高度的该比例后显示「返回顶部」。
  static const double scrollToTopShowFraction = 0.15;

  /// 已显示时，低于该比例才隐藏（滞回，避免边界抖动）。
  static const double scrollToTopHideFraction = 0.05;

  /// 距页底超过视口该比例时显示「下一楼」。
  static const double scrollDownShowFraction = 0.12;

  /// 已显示时，距页底低于该比例才隐藏（滞回）。
  static const double scrollDownHideFraction = 0.04;

  static const double edgeMargin = 16;
  static const double stackGap = 12;
  static const double regularFabSize = 56;

  /// 滚动导航组：单颗图标按钮边长。
  static const double navButtonSize = 40;

  /// 滚动导航组：容器内边距。
  static const double navGroupPadding = 4;

  /// 滚动导航组：↑ 与 ↓ 之间的间距（含分隔线）。
  static const double navGroupInnerGap = 4;

  /// 分页栏内容高度（不含 SafeArea），供 SnackBar 避让。
  static const double paginationBarHeight = S1BottomBarStyle.paginationBarHeight;
  static const double snackBarGap = 8;

  static double get snackBarClearance => paginationBarHeight + snackBarGap;

  /// 滚动导航组高度（0 表示不显示）。
  static double scrollNavGroupHeight({
    bool showScrollToTop = false,
    bool showScrollDown = false,
  }) {
    if (!showScrollToTop && !showScrollDown) return 0;

    var count = 0;
    if (showScrollToTop) count++;
    if (showScrollDown) count++;

    var height = navGroupPadding * 2 + count * navButtonSize;
    if (count > 1) {
      height += navGroupInnerGap + 1;
    }
    return height;
  }

  /// FAB 纵列高度：滚动导航组（上）+ 主 FAB（下）。
  static double stackHeight({
    bool showScrollNavTop = false,
    bool showScrollNavDown = false,
    bool showPrimary = false,
  }) {
    var height = scrollNavGroupHeight(
      showScrollToTop: showScrollNavTop,
      showScrollDown: showScrollNavDown,
    );
    if (showPrimary) {
      if (height > 0) height += stackGap;
      height += regularFabSize;
    }
    return height;
  }

  /// ListView 底部留白，避免最后一条内容被 FAB 遮挡。
  static double contentBottomPadding({
    bool showScrollNavTop = false,
    bool showScrollNavDown = false,
    bool showPrimary = false,
  }) {
    final stack = stackHeight(
      showScrollNavTop: showScrollNavTop,
      showScrollNavDown: showScrollNavDown,
      showPrimary: showPrimary,
    );
    if (stack == 0) return edgeMargin;
    return edgeMargin + stack + edgeMargin;
  }

  /// 是否应显示「返回顶部」FAB（视口比例 + 滞回）。
  static bool shouldShowScrollToTop({
    required S1ScrollMetrics metrics,
    required bool currentlyShowing,
  }) {
    final viewport = metrics.viewportDimension;
    if (viewport <= 0) return false;

    final showThreshold = viewport * scrollToTopShowFraction;
    final hideThreshold = viewport * scrollToTopHideFraction;
    if (currentlyShowing) {
      return metrics.offset > hideThreshold;
    }
    return metrics.offset > showThreshold;
  }

  /// 是否应显示「下一楼」FAB（距页底比例 + 滞回）。
  static bool shouldShowScrollDown({
    required S1ScrollMetrics metrics,
    required bool currentlyShowing,
  }) {
    final viewport = metrics.viewportDimension;
    if (viewport <= 0) return false;
    if (metrics.maxScrollExtent <= 0) return false;

    final remaining = metrics.maxScrollExtent - metrics.offset;
    final showThreshold = viewport * scrollDownShowFraction;
    final hideThreshold = viewport * scrollDownHideFraction;
    if (currentlyShowing) {
      return remaining > hideThreshold;
    }
    return remaining > showThreshold;
  }
}

/// 滚动导航组配置（↑ 返回顶部 / ↓ 下一楼）。
class S1ScrollNavConfig {
  const S1ScrollNavConfig({
    required this.showScrollToTop,
    required this.showScrollDown,
    this.onScrollToTop,
    this.onScrollToNextFloor,
    this.onScrollToBottom,
  });

  final bool showScrollToTop;
  final bool showScrollDown;
  final VoidCallback? onScrollToTop;
  final VoidCallback? onScrollToNextFloor;
  final VoidCallback? onScrollToBottom;

  bool get isVisible => showScrollToTop || showScrollDown;
}

/// ↑↓ 滚动导航组：弱样式竖条，与主 FAB 视觉分离。
class S1ScrollNavGroup extends StatelessWidget {
  const S1ScrollNavGroup({super.key, required this.config});

  final S1ScrollNavConfig config;

  @override
  Widget build(BuildContext context) {
    if (!config.isVisible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (config.showScrollToTop) {
      children.add(
        _NavIconButton(
          key: const ValueKey('scroll_nav_up'),
          icon: Icons.arrow_upward,
          tooltip: '返回顶部',
          onPressed: config.onScrollToTop!,
        ),
      );
    }

    if (config.showScrollToTop && config.showScrollDown) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: S1Alpha.subtle),
          ),
        ),
      );
      if (S1FabLayout.navGroupInnerGap > 1) {
        children.add(const SizedBox(height: S1FabLayout.navGroupInnerGap - 1));
      }
    }

    if (config.showScrollDown) {
      children.add(
        _NavDoubleTapButton(
          key: const ValueKey('scroll_nav_down'),
          icon: Icons.arrow_downward,
          tooltip: '下一楼 · 双击到底部',
          semanticLabel: '下一楼',
          semanticHint: '双击跳至页底',
          onTap: config.onScrollToNextFloor!,
          onDoubleTap: config.onScrollToBottom!,
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: S1Shape.large),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(S1FabLayout.navGroupPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 22,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: S1FabLayout.navButtonSize,
          height: S1FabLayout.navButtonSize,
        ),
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _NavDoubleTapButton extends StatelessWidget {
  const _NavDoubleTapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.onDoubleTap,
    this.semanticLabel,
    this.semanticHint,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: S1FabLayout.navButtonSize,
              height: S1FabLayout.navButtonSize,
              child: Icon(
                icon,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个主 FAB 配置。
class S1FabItem {
  const S1FabItem({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.visible = true,
  });

  final Object heroTag;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool visible;
}

/// 内容区右下角 FAB 纵列：滚动导航组（上）+ 主操作 FAB（下）。
class S1FabStack extends StatelessWidget {
  const S1FabStack({
    super.key,
    this.scrollNav,
    this.primary,
  });

  /// 滚动导航（↑↓），弱样式竖条。
  final S1ScrollNavConfig? scrollNav;

  /// 主操作（如回复 / 发帖）。
  final S1FabItem? primary;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (scrollNav != null && scrollNav!.isVisible) {
      children.add(S1ScrollNavGroup(config: scrollNav!));
    }
    if (primary != null && primary!.visible) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: S1FabLayout.stackGap));
      }
      children.add(
        FloatingActionButton(
          heroTag: primary!.heroTag,
          onPressed: primary!.onPressed,
          tooltip: primary!.tooltip,
          child: Icon(primary!.icon),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
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
