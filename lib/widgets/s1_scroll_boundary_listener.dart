import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/boundary_feedback.dart';

/// 纵滑触底越界监听：仅在 [isTerminal] 时反馈（末页 / 无更多）。
///
/// 传入 [onRefresh] 时，手指还在拖的正向 overscroll 立刻刷新一次；
/// 甩到底的惯性 / 回弹（[OverscrollNotification.dragDetails] 为空）只给触觉，不请求。
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

  /// 末端主动上划：同一手势只触发一次。
  final Future<void> Function()? onRefresh;

  @override
  State<S1ScrollBoundaryListener> createState() =>
      _S1ScrollBoundaryListenerState();
}

class _S1ScrollBoundaryListenerState extends State<S1ScrollBoundaryListener> {
  bool _refreshDispatchedThisGesture = false;

  bool _onNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      _refreshDispatchedThisGesture = false;
      return false;
    }
    if (!widget.isTerminal) return false;
    if (notification is! OverscrollNotification) return false;
    // 正向 overscroll：试图滚过 maxScrollExtent（触底再往下）。
    if (notification.overscroll <= 0) return false;
    final metrics = notification.metrics;
    if (!metrics.hasPixels || !metrics.hasContentDimensions) return false;
    if (metrics.pixels < metrics.maxScrollExtent - 1) return false;

    widget.feedback.hit(
      context,
      widget.edge,
      message: widget.message,
      showMessage: widget.onRefresh == null,
    );
    if (widget.onRefresh != null &&
        notification.dragDetails != null &&
        !_refreshDispatchedThisGesture) {
      _refreshDispatchedThisGesture = true;
      unawaited(widget.onRefresh!());
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
