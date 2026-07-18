import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';

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
///
/// **滚动与底部留白护栏**（违反会导致回弹 / 图标与位置不一致）：
/// 1. Padding 固定：构建时确定，不随 FAB 显隐或滚动 metrics 变化。
/// 2. 帖子详情始终按 [threadDetailMaxFabStackHeight] 预留（含回复 FAB 槽位）。
/// 3. 单一滚动终点：手动滑到底 / 长按 ↓ 一律 `maxScrollExtent`。
/// 4. FAB 判定只读滚动：显隐只驱动 [ValueNotifier] 等局部刷新，禁止重建列表。
abstract class S1FabLayout {
  /// 滚动超过视口高度的该比例后显示「返回顶部」。
  static const double scrollToTopShowFraction = 0.15;

  /// 已显示时，低于该比例才隐藏（滞回，避免边界抖动）。
  static const double scrollToTopHideFraction = 0.05;

  /// 距页底超过视口该比例时显示「下一楼」。
  static const double scrollDownShowFraction = 0.12;

  /// 视为「已滚到末尾」的容差（与自然滑到底、长按 ↓ 对齐）。
  static const double scrollEndTolerance = 1;

  static const double edgeMargin = 16;
  static const double stackGap = 12;
  static const double regularFabSize = 56;

  /// 滚动导航组：单颗图标按钮边长。
  static const double navButtonSize = 40;

  /// 滚动导航组：图标尺寸。
  static const double navIconSize = 22;

  /// 滚动导航组：容器内边距。
  static const double navGroupPadding = 4;

  /// 滚动导航组：固定宽度（三种显示状态一致）。
  static const double navGroupWidth = navButtonSize + navGroupPadding * 2;

  /// 滚动导航组：↑ 与 ↓ 之间的间距（含分隔线）。
  static const double navGroupInnerGap = 4;

  /// 分页栏内容高度（不含 SafeArea），供 SnackBar 避让。
  static const double paginationBarHeight =
      S1BottomBarStyle.paginationBarHeight;
  static const double snackBarGap = 8;

  static double get snackBarClearance => paginationBarHeight + snackBarGap;

  /// 滚动导航组高度（0 表示不显示）。仅用于几何常量计算。
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

  /// 帖子详情 FAB 纵列最大高度（↑+↓ 同组 + 主 FAB，稳定常量）。
  static double get threadDetailMaxFabStackHeight {
    final nav = scrollNavGroupHeight(
      showScrollToTop: true,
      showScrollDown: true,
    );
    return nav + stackGap + regularFabSize;
  }

  /// 轻量场景底部留白（如版块列表，仅 ↑）。
  static const EdgeInsets scrollBottomPadding =
      EdgeInsets.only(bottom: edgeMargin);

  /// 帖子详情底部留白（固定最大 FAB 栈高，与登录/显隐无关）。
  static final EdgeInsets threadDetailScrollBottomPadding =
      EdgeInsets.only(bottom: threadDetailMaxFabStackHeight);

  /// 帖子详情列表预缓存范围。略大于默认 250，避免一次预建过多楼层
  ///（链接墙楼层仍在视野时，过大数据会加重同帧卡顿）。
  static const ScrollCacheExtent threadDetailScrollCacheExtent =
      ScrollCacheExtent.pixels(400);

  /// 距滚动末尾还剩多少。
  static double _remainingToEnd(S1ScrollMetrics metrics) =>
      metrics.maxScrollExtent - metrics.offset;

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

  /// 是否应显示「下一楼」FAB（距末楼贴底比例 + 滞回）。
  static bool shouldShowScrollDown({
    required S1ScrollMetrics metrics,
    required bool currentlyShowing,
  }) {
    final viewport = metrics.viewportDimension;
    if (viewport <= 0) return false;
    if (metrics.maxScrollExtent <= 0) return false;

    final remaining = _remainingToEnd(metrics);
    final showThreshold = viewport * scrollDownShowFraction;
    if (currentlyShowing) {
      return remaining > scrollEndTolerance;
    }
    return remaining > showThreshold;
  }

  /// 是否已到达当前页末尾（与 [scrollToBottom] / 手动滑到底对齐）。
  static bool isAtPageBottom({
    required S1ScrollMetrics metrics,
    required bool currentlyAtBottom,
  }) {
    final viewport = metrics.viewportDimension;
    if (viewport <= 0) return false;
    if (metrics.maxScrollExtent <= 0) return true;

    final remaining = _remainingToEnd(metrics);
    if (currentlyAtBottom) {
      return remaining <= viewport * scrollDownShowFraction;
    }
    return remaining <= scrollEndTolerance;
  }
}

/// ↓ 导航按钮模式：页内下一楼 / 页底进入下一页。
enum ScrollNavAdvanceMode {
  nextFloor,
  nextPage,
}

/// 滚动导航组配置（↑ 返回顶部 / ↓·→ 向下推进）。
class S1ScrollNavConfig {
  const S1ScrollNavConfig({
    required this.showScrollToTop,
    required this.showScrollAdvance,
    this.advanceMode = ScrollNavAdvanceMode.nextFloor,
    this.onScrollToTop,
    this.onScrollToNextFloor,
    this.onScrollToBottom,
    this.onGoToNextPage,
  });

  final bool showScrollToTop;

  /// 是否显示 ↓ / → 推进按钮位。
  final bool showScrollAdvance;
  final ScrollNavAdvanceMode advanceMode;
  final VoidCallback? onScrollToTop;
  final VoidCallback? onScrollToNextFloor;
  final VoidCallback? onScrollToBottom;
  final VoidCallback? onGoToNextPage;

  bool get isVisible => showScrollToTop || showScrollAdvance;
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
        _NavActionButton(
          key: const ValueKey('scroll_nav_up'),
          icon: Icons.keyboard_double_arrow_up,
          tooltip: '返回顶部',
          onPressed: config.onScrollToTop!,
        ),
      );
    }

    if (config.showScrollToTop && config.showScrollAdvance) {
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

    if (config.showScrollAdvance) {
      final isNextPage = config.advanceMode == ScrollNavAdvanceMode.nextPage;
      children.add(
        _NavActionButton(
          key: ValueKey(isNextPage ? 'scroll_nav_forward' : 'scroll_nav_down'),
          icon: isNextPage ? Icons.arrow_forward : Icons.arrow_downward,
          longPressIcon: isNextPage ? null : Icons.keyboard_double_arrow_down,
          iconKey: ValueKey(
            isNextPage ? 'scroll_nav_forward_icon' : 'scroll_nav_down_icon',
          ),
          tooltip: isNextPage ? '下一页（长按到底部）' : '下一楼（长按到底部）',
          semanticLabel: isNextPage ? '下一页' : '下一楼',
          semanticHint: '长按跳至页底',
          onPressed:
              isNextPage ? config.onGoToNextPage! : config.onScrollToNextFloor!,
          onLongPress: config.onScrollToBottom,
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: S1Shape.large,
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: S1FabLayout.navGroupWidth,
        child: Padding(
          padding: const EdgeInsets.all(S1FabLayout.navGroupPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// 导航组内统一尺寸的图标按钮（可选长按）。
class _NavActionButton extends StatefulWidget {
  const _NavActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconKey,
    this.longPressIcon,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
  });

  final IconData icon;
  final IconData? longPressIcon;
  final Key? iconKey;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<_NavActionButton> createState() => _NavActionButtonState();
}

class _NavActionButtonState extends State<_NavActionButton> {
  bool _longPressActivated = false;

  void _onTap() {
    S1Haptics.selection();
    if (_longPressActivated) {
      setState(() => _longPressActivated = false);
    }
    widget.onPressed();
  }

  void _onLongPress() {
    S1Haptics.medium();
    if (widget.longPressIcon != null) {
      setState(() => _longPressActivated = true);
    }
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        hint: widget.semanticHint,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onTap,
            onLongPress: widget.onLongPress == null ? null : _onLongPress,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: S1FabLayout.navButtonSize,
              height: S1FabLayout.navButtonSize,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale:
                          Tween<double>(begin: 0.84, end: 1).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  _activeIcon,
                  key: ValueKey((widget.iconKey, _activeIcon)),
                  size: S1FabLayout.navIconSize,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _activeIcon =>
      _longPressActivated ? widget.longPressIcon ?? widget.icon : widget.icon;
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
