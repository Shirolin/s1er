import 'package:flutter/material.dart';

import '../theme/s1_haptics.dart';
import '../utils/scroll_motion.dart';
import 's1_fab_layout.dart';

typedef S1PageBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

typedef S1PageChangeCallback = Future<void> Function(int page);

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
    this.enabled = true,
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

  /// 是否启用左右滑动（单页时自动禁用）。
  final bool enabled;

  @override
  State<S1SwipePagination> createState() => S1SwipePaginationState();
}

class S1SwipePaginationState extends State<S1SwipePagination> {
  static const int _centerSlot = 1;

  late PageController _pageController;
  late ScrollController _scrollController;
  bool _isPaging = false;
  int? _pendingPage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _centerSlot);
    _scrollController = _createScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyScrollMetrics();
    });
  }

  @override
  void didUpdateWidget(covariant S1SwipePagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage &&
        widget.currentPage != _pendingPage) {
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
        _scrollController.jumpTo(0);
      }
      _notifyScrollMetrics();
      if (_pageController.hasClients &&
          _pageController.page?.round() != _centerSlot) {
        _pageController.jumpToPage(_centerSlot);
      }
    });
  }

  void _notifyScrollMetrics() {
    if (!_scrollController.hasClients) {
      widget.onScrollMetricsChanged?.call(
        const S1ScrollMetrics(
          offset: 0,
          viewportDimension: 0,
          maxScrollExtent: 0,
        ),
      );
      return;
    }
    final position = _scrollController.position;
    widget.onScrollMetricsChanged?.call(
      S1ScrollMetrics(
        offset: position.pixels,
        viewportDimension: position.viewportDimension,
        maxScrollExtent: position.maxScrollExtent,
      ),
    );
  }

  void _onScroll() => _notifyScrollMetrics();

  /// 将当前页滚动回顶部（供 FAB 等外部调用）。
  Future<void> scrollToTop() async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    await S1ScrollMotion.animateTo(position, position.minScrollExtent);
  }

  /// 将当前页滚动到底部。
  ///
  /// [ListView.builder] 等在滚动中会逐步构建子项，[maxScrollExtent] 可能在
  /// 动画过程中增长；单次 [animateTo] 会停在过期的 extent，故循环校正。
  Future<void> scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    await S1ScrollMotion.animateToMaxExtent(_scrollController.position);
  }

  bool get _canSwipeToPrevious => widget.currentPage > 1;

  bool get _canSwipeToNext => widget.currentPage < widget.totalPages;

  bool get _usePageView => widget.enabled && widget.totalPages > 1;

  ScrollPhysics get _pagePhysics => _BoundedSwipePaginationPhysics(
        canSwipeToPrevious: _canSwipeToPrevious,
        canSwipeToNext: _canSwipeToNext,
      );

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
        child: widget.pageBuilder(context, _scrollController),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: const SizedBox.expand(),
    );
  }

  Widget _buildPagedBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isPaging)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: scheme.surfaceContainer,
            color: scheme.primary,
          ),
        Expanded(
          child: Semantics(
            label: '左右滑动可翻页',
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  _snapToNearestSlot();
                }
                return false;
              },
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
    return widget.pageBuilder(context, _scrollController);
  }

  @override
  Widget build(BuildContext context) {
    if (!_usePageView) {
      return _buildSinglePageBody(context);
    }
    return _buildPagedBody(context);
  }
}

/// 限制首尾页越界滑动，并修正中心页双向甩动吸附不对称的问题。
class _BoundedSwipePaginationPhysics extends PageScrollPhysics {
  const _BoundedSwipePaginationPhysics({
    required this.canSwipeToPrevious,
    required this.canSwipeToNext,
    super.parent,
  });

  final bool canSwipeToPrevious;
  final bool canSwipeToNext;

  @override
  _BoundedSwipePaginationPhysics applyTo(ScrollPhysics? ancestor) {
    return _BoundedSwipePaginationPhysics(
      canSwipeToPrevious: canSwipeToPrevious,
      canSwipeToNext: canSwipeToNext,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!position.hasViewportDimension || position.viewportDimension == 0) {
      return super.applyBoundaryConditions(position, value);
    }

    final currentIndex = _pageIndex(position);

    if (!canSwipeToPrevious && value < position.pixels && currentIndex <= 1) {
      return value - position.pixels;
    }
    if (!canSwipeToNext && value > position.pixels && currentIndex >= 1) {
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
      if (!canSwipeToPrevious) {
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
      if (!canSwipeToNext) {
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
