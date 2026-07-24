import 'package:flutter/material.dart';

import '../utils/boundary_feedback.dart';

/// 纵滑触底越界监听：仅在 [isTerminal] 时反馈（末页 / 无更多）。
class S1ScrollBoundaryListener extends StatelessWidget {
  const S1ScrollBoundaryListener({
    super.key,
    required this.isTerminal,
    required this.feedback,
    required this.child,
    this.message,
    this.edge = BoundaryEdge.listEnd,
  });

  /// 是否处于列表/分页末端（非末端不打扰，靠页脚引导翻页）。
  final bool isTerminal;

  final BoundaryFeedbackController feedback;
  final Widget child;
  final String? message;
  final BoundaryEdge edge;

  bool _onNotification(BuildContext context, ScrollNotification notification) {
    if (!isTerminal) return false;
    if (notification is! OverscrollNotification) return false;
    // 正向 overscroll：试图滚过 maxScrollExtent（触底再往下）。
    if (notification.overscroll <= 0) return false;
    final metrics = notification.metrics;
    if (!metrics.hasPixels || !metrics.hasContentDimensions) return false;
    if (metrics.pixels < metrics.maxScrollExtent - 1) return false;

    feedback.hit(context, edge, message: message);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => _onNotification(context, notification),
      child: child,
    );
  }
}
