import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/boundary_feedback.dart';
import '../utils/scroll_motion.dart';
import 's1_fab_layout.dart';
import 's1_scroll_boundary_listener.dart';
import 'skeleton/s1_swipe_adjacent_skeleton.dart';

export 'skeleton/s1_swipe_adjacent_skeleton.dart'
    show S1SwipeAdjacentSkeletonStyle;

typedef S1PageBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

typedef S1PageChangeCallback = Future<void> Function(int page);

typedef S1PageBoundaryCallback = void Function(BoundaryEdge edge);

/// 三槽 [PageView] 左右滑动翻页，与底部分页栏双向同步。
///
/// 始终将当前页放在中间槽（index 1），滑动到两侧槽后触发 [onPageChanged]，
/// 数据返回后重置回中心槽。
class S1SwipePagination extends StatefulWidget {
  const S1SwipePagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.pageBuilder,
    this.onScrollMetricsChanged,
    this.onBoundaryHit,
    this.boundaryFeedback,
    this.onTerminalRefresh,
    this.enabled = true,
    this.showPagingIndicator = true,
    this.adjacentSkeletonStyle = S1SwipeAdjacentSkeletonStyle.generic,
  });

  /// 当前页码（1-based）。
  final int currentPage;

  /// 总页数。
  final int totalPages;

  /// 翻页回调（滑动或外部分页栏触发后由父级调用 API）。
  final S1PageChangeCallback onPageChanged;

  /// 构建当前页可滚动内容。
  final S1PageBuilder pageBuilder;

  /// 当前页滚动状态，供 FAB「返回顶部」等使用。
  final ValueChanged<S1ScrollMetrics>? onScrollMetricsChanged;

  /// 首/末页横滑越界（便于测试）；默认走 [boundaryFeedback]。
  final S1PageBoundaryCallback? onBoundaryHit;

  /// 越界节流控制器；为 null 时使用内部默认实例。
  final BoundaryFeedbackController? boundaryFeedback;

  /// 末页纵滑触底再拉：冷却窗内第二次越界时刷新当前页（由父级实现）。
  final Future<void> Function()? onTerminalRefresh;

  /// 是否启用左右滑动（单页时自动禁用）。
  final bool enabled;

  /// 滑动翻页时是否在内容区顶部显示进度条。
  ///
  /// 父级已用 [state.isLoading] 等统一指示加载时（如版块列表筛选栏上方）应关闭，
  /// 避免与父级进度条叠成两条。
  final bool showPagingIndicator;

  /// 左右侧槽横滑预览用的列表骨架样式（不含真实邻页数据）。
  final S1SwipeAdjacentSkeletonStyle adjacentSkeletonStyle;

  @override
  State<S1SwipePagination> createState() => S1SwipePaginationState();
}

class S1SwipePaginationState extends State<S1SwipePagination> {
  static const int _centerSlot = 1;

  late PageController _pageController;
  late ScrollController _scrollController;
  late BoundaryFeedbackController _boundaryFeedback;
  bool _isPaging = false;
  int? _pendingPage;

  @override
  void initState() {
    super.initState();
    _boundaryFeedback = widget.boundaryFeedback ?? BoundaryFeedbackController();
    _pageController = PageController(initialPage: _centerSlot);
    _scrollController = _createScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleScrollMetricsNotification();
    });
  }

  @override
  void didUpdateWidget(covariant S1SwipePagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.boundaryFeedback != null &&
        widget.boundaryFeedback != oldWidget.boundaryFeedback) {
      _boundaryFeedback = widget.boundaryFeedback!;
    }
    if (oldWidget.currentPage != widget.currentPage &&
        widget.currentPage != _pendingPage) {
      _boundaryFeedback.reset();
      _resetScrollForPageChange();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  ScrollController _createScrollController() {
    final controller = ScrollController();
    controller.addListener(_onScroll);
    return controller;
  }

  void _replaceScrollController() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollController = _createScrollController();
  }

  /// 翻页后回到新页顶部（底栏翻页不经 [_requestPage]，也须重置）。
  void _resetScrollForPageChange() {
    _replaceScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        for (final position in _scrollController.positions) {
          if (position.hasContentDimensions) {
            position.jumpTo(0);
          }
        }
      }
      _realignPageViewToCenter();
      _scheduleScrollMetricsNotification();
    });
  }

  /// 外部分页栏 / 跳转最新等不经 [_requestPage] 的换页后，复位中心槽。
  /// 滑动翻页由 [_requestPage] 自行收尾，此处直接跳过，避免重复复位。
  void syncAfterExternalPageChange() {
    if (_isPaging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _realignPageViewToCenter();
      _scheduleScrollMetricsNotification();
    });
  }

  void _realignPageViewToCenter() {
    if (_pageController.hasClients &&
        _pageController.page?.round() != _centerSlot) {
      _pageController.jumpToPage(_centerSlot);
    }
  }

  void _scheduleScrollMetricsNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_notifyScrollMetrics()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifyScrollMetrics();
      });
    });
  }

  /// 返回 `true` 表示已上报有效 metrics。
  bool _notifyScrollMetrics() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return false;
    }
    final position = _scrollController.position;
    widget.onScrollMetricsChanged?.call(
      S1ScrollMetrics(
        offset: position.pixels,
        viewportDimension: position.viewportDimension,
        maxScrollExtent: position.maxScrollExtent,
      ),
    );
    return true;
  }

  void _onScroll() => _notifyScrollMetrics();

  /// 将当前页滚动回顶部（供 FAB 等外部调用）。
  Future<void> scrollToTop() async {
    if (!_scrollController.hasClients) return;
    for (final position in _scrollController.positions) {
      if (position.hasContentDimensions) {
        await S1ScrollMotion.animateTo(position, position.minScrollExtent);
      }
    }
  }

  /// 刷新完成后复位触底节流，便于下一次手势重新走触觉 → 刷新。
  void resetBoundaryFeedback() {
    _boundaryFeedback.reset();
  }

  /// 将当前页滚动到底部。
  ///
  /// [ListView.builder] 等在滚动中会逐步构建子项，[maxScrollExtent] 可能在
  /// 动画过程中增长；单次 [animateTo] 会停在过期的 extent，故循环校正。
  Future<void> scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    for (final position in _scrollController.positions) {
      if (position.hasContentDimensions) {
        await S1ScrollMotion.animateToMaxExtent(position);
      }
    }
  }

  bool get _canSwipeToPrevious => widget.currentPage > 1;

  bool get _canSwipeToNext => widget.currentPage < widget.totalPages;

  bool get _usePageView => widget.enabled && widget.totalPages > 1;

  ScrollPhysics get _pagePhysics => BoundedSwipePaginationPhysics(
        getCurrentPage: () => widget.currentPage,
        getTotalPages: () => widget.totalPages,
      );

  void _onHorizontalBoundaryBlocked(BoundaryEdge edge) {
    widget.onBoundaryHit?.call(edge);
    if (!mounted) return;
    _boundaryFeedback.hit(context, edge);
  }

  bool _onPageViewScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollEndNotification) {
      _snapToNearestSlot();
      return false;
    }
    if (notification is! OverscrollNotification) return false;
    if (!_pageController.hasClients) return false;

    final page = _pageController.page;
    if (page == null) return false;
    // 中心槽附近才认首末越界，避免翻页动画中误触。
    if ((page - _centerSlot).abs() > 0.05) return false;

    if (notification.overscroll < 0 && !_canSwipeToPrevious) {
      _onHorizontalBoundaryBlocked(BoundaryEdge.firstPage);
    } else if (notification.overscroll > 0 && !_canSwipeToNext) {
      _onHorizontalBoundaryBlocked(BoundaryEdge.lastPage);
    }
    return false;
  }

  Future<void> _requestPage(int page) async {
    if (_isPaging || page == widget.currentPage) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_centerSlot);
      }
      return;
    }

    setState(() {
      _isPaging = true;
      _pendingPage = page;
    });
    S1Haptics.selection();

    try {
      await widget.onPageChanged(page);
    } finally {
      if (mounted) {
        _resetScrollForPageChange();
        setState(() {
          _isPaging = false;
          _pendingPage = null;
        });
      }
    }
  }

  void _onSlotChanged(int index) {
    if (index == _centerSlot || _isPaging) return;

    final targetPage =
        index < _centerSlot ? widget.currentPage - 1 : widget.currentPage + 1;

    if (targetPage < 1 || targetPage > widget.totalPages) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_centerSlot);
      }
      return;
    }

    _requestPage(targetPage);
  }

  void _snapToNearestSlot() {
    if (!_pageController.hasClients || _isPaging) return;

    final page = _pageController.page;
    if (page == null) return;

    final nearest = page.round();
    if (nearest != page) {
      _pageController.animateToPage(
        nearest,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildSlotContent(BuildContext context, int slot) {
    if (slot == _centerSlot) {
      return KeyedSubtree(
        key: ValueKey(widget.currentPage),
        child: S1ScrollBoundaryListener(
          isTerminal: widget.currentPage >= widget.totalPages,
          feedback: _boundaryFeedback,
          onRefresh: widget.onTerminalRefresh,
          child: widget.pageBuilder(context, _scrollController),
        ),
      );
    }

    final canShowSkeleton =
        slot < _centerSlot ? _canSwipeToPrevious : _canSwipeToNext;

    if (!canShowSkeleton) {
      return ColoredBox(
        key: ValueKey('s1-swipe-slot-placeholder-$slot'),
        color: S1Surface.page(Theme.of(context).colorScheme),
        child: const SizedBox.expand(),
      );
    }

    return KeyedSubtree(
      key: ValueKey('s1-swipe-slot-skeleton-$slot'),
      child: S1SwipeAdjacentSkeleton(style: widget.adjacentSkeletonStyle),
    );
  }

  Widget _buildPagedBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isPaging && widget.showPagingIndicator)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: scheme.surfaceContainer,
            color: scheme.primary,
          ),
        Expanded(
          child: Semantics(
            label: '左右滑动可翻页',
            child: NotificationListener<ScrollNotification>(
              onNotification: _onPageViewScrollNotification,
              child: PageView(
                controller: _pageController,
                onPageChanged: _onSlotChanged,
                // 使用自定义 PageScrollPhysics 处理吸附，避免默认 round(0.5)==1
                // 导致中心页向右甩动无法翻上一页。
                pageSnapping: false,
                physics: _isPaging
                    ? const NeverScrollableScrollPhysics()
                    : _pagePhysics,
                children: List.generate(
                  3,
                  (index) => _buildSlotContent(context, index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePageBody(BuildContext context) {
    return S1ScrollBoundaryListener(
      isTerminal: true,
      feedback: _boundaryFeedback,
      onRefresh: widget.onTerminalRefresh,
      child: widget.pageBuilder(context, _scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_usePageView) {
      return _buildSinglePageBody(context);
    }
    return _buildPagedBody(context);
  }
}

typedef PageIndexGetter = int Function();

/// 限制首尾页越界滑动，并修正中心页双向甩动吸附不对称的问题。
///
/// [getCurrentPage] / [getTotalPages] 在每次手势计算时读取，避免 ScrollPosition
/// 复用旧 physics 实例时仍按创建时的页码锁死横滑。
@visibleForTesting
class BoundedSwipePaginationPhysics extends PageScrollPhysics {
  // 含运行时页码回调，无法 const。
  // ignore: prefer_const_constructors_in_immutables
  BoundedSwipePaginationPhysics({
    required this.getCurrentPage,
    required this.getTotalPages,
    super.parent,
  });

  final PageIndexGetter getCurrentPage;
  final PageIndexGetter getTotalPages;

  bool get _canSwipeToPrevious => getCurrentPage() > 1;

  bool get _canSwipeToNext => getCurrentPage() < getTotalPages();

  @override
  BoundedSwipePaginationPhysics applyTo(ScrollPhysics? ancestor) {
    return BoundedSwipePaginationPhysics(
      getCurrentPage: getCurrentPage,
      getTotalPages: getTotalPages,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!position.hasViewportDimension || position.viewportDimension == 0) {
      return super.applyBoundaryConditions(position, value);
    }

    final currentIndex = _pageIndex(position);

    if (!_canSwipeToPrevious && value < position.pixels && currentIndex <= 1) {
      return value - position.pixels;
    }
    if (!_canSwipeToNext && value > position.pixels && currentIndex >= 1) {
      return value - position.pixels;
    }

    return super.applyBoundaryConditions(position, value);
  }

  double _pageIndex(ScrollMetrics position) {
    if (position is PageMetrics && position.page != null) {
      return position.page!;
    }
    return position.pixels / position.viewportDimension;
  }

  double _pagePixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    var page = _pageIndex(position);

    if (velocity < -tolerance.velocity) {
      if (!_canSwipeToPrevious) {
        return null;
      }
      page -= 0.5;
      final target = _pagePixels(position, page.floorToDouble());
      if (target != position.pixels) {
        return ScrollSpringSimulation(
          spring,
          position.pixels,
          target,
          velocity,
          tolerance: tolerance,
        );
      }
      return null;
    }

    if (velocity > tolerance.velocity) {
      if (!_canSwipeToNext) {
        return null;
      }
      page += 0.5;
      final target = _pagePixels(position, page.ceilToDouble());
      if (target != position.pixels) {
        return ScrollSpringSimulation(
          spring,
          position.pixels,
          target,
          velocity,
          tolerance: tolerance,
        );
      }
      return null;
    }

    final target = _pagePixels(position, page.roundToDouble());
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }
}
