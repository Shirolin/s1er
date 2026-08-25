import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/boundary_feedback.dart';

/// 纵滑触底越界监听：仅在 [isTerminal] 时反馈（末页 / 无更多）。
///
/// 传入 [onRefresh] 时，冷却窗内第二次触底改为触发刷新，而不再弹出默认文案；
/// 同一连续手势只刷新一次。
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

  /// 末页触底再拉：冷却窗内第二次越界时触发。
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

    final repeating = widget.feedback.hit(
      context,
      widget.edge,
      message: widget.message,
      showMessage: widget.onRefresh == null,
    );
    if (repeating &&
        widget.onRefresh != null &&
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
