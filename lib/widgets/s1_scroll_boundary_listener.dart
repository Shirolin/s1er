import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/boundary_feedback.dart';

/// 纵滑触底越界监听：仅在 [isTerminal] 时反馈（末页 / 无更多）。
///
/// 传入 [onRefresh] 时，第一次触底只给触觉；松手后再拉一次（冷却窗内）才刷新。
/// 同一手势里的回弹 / 惯性 overscroll 不会触发刷新。
class S1ScrollBoundaryListener extends StatefulWidget {
  const S1ScrollBoundaryListener({
    super.key,
    required this.isTerminal,
    required this.feedback,
    required this.child,
    this.message,
    this.edge = BoundaryEdge.listEnd,
    this.onRefresh,
  });

  /// 是否处于列表/分页末端（非末端不打扰，靠页脚引导翻页）。
  final bool isTerminal;

  final BoundaryFeedbackController feedback;
  final Widget child;
  final String? message;
  final BoundaryEdge edge;

  /// 末页触底再拉：上一次触底手势结束后的下一次越界时触发。
  final Future<void> Function()? onRefresh;

  @override
  State<S1ScrollBoundaryListener> createState() =>
      _S1ScrollBoundaryListenerState();
}

class _S1ScrollBoundaryListenerState extends State<S1ScrollBoundaryListener> {
  bool _refreshDispatchedThisGesture = false;
  bool _sawTerminalOverscrollThisGesture = false;
  bool _endedSinceTerminalHit = false;

  bool _onNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      _refreshDispatchedThisGesture = false;
      if (_sawTerminalOverscrollThisGesture) {
        _endedSinceTerminalHit = true;
      }
      _sawTerminalOverscrollThisGesture = false;
      return false;
    }
    if (!widget.isTerminal) return false;
    if (notification is! OverscrollNotification) return false;
    // 正向 overscroll：试图滚过 maxScrollExtent（触底再往下）。
    if (notification.overscroll <= 0) return false;
    final metrics = notification.metrics;
    if (!metrics.hasPixels || !metrics.hasContentDimensions) return false;
    if (metrics.pixels < metrics.maxScrollExtent - 1) return false;

    _sawTerminalOverscrollThisGesture = true;
    final repeating = widget.feedback.hit(
      context,
      widget.edge,
      message: widget.message,
      showMessage: widget.onRefresh == null,
    );
    if (repeating &&
        widget.onRefresh != null &&
        _endedSinceTerminalHit &&
        !_refreshDispatchedThisGesture) {
      _refreshDispatchedThisGesture = true;
      _endedSinceTerminalHit = false;
      unawaited(widget.onRefresh!());
    } else if (!repeating) {
      // 新的「第一次触底」：丢掉更早一次滚动留下的 ended，避免同一次回弹刷新。
      _endedSinceTerminalHit = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}
