import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 帖子详情「下一楼」滚动：定位当前阅读楼并滚至下一楼靠上展示。
abstract class ScrollFloorNavigator {
  /// 下一楼目标在视口中的纵向对齐（靠上阅读区）。
  static const double revealAlignment = 0.08;

  static const Duration scrollDuration = Duration(milliseconds: 300);
  static const Curve scrollCurve = Curves.easeOutCubic;

  /// 单击「下一楼」：将下一楼滚至 [revealAlignment]；末楼时调用 [onAtLastFloor]。
  static Future<void> scrollToNextFloor({
    required List<GlobalKey> postKeys,
    required VoidCallback onAtLastFloor,
  }) async {
    if (postKeys.isEmpty) {
      onAtLastFloor();
      return;
    }

    BuildContext? anchorContext;
    for (final key in postKeys) {
      if (key.currentContext != null) {
        anchorContext = key.currentContext;
        break;
      }
    }
    if (anchorContext == null) {
      onAtLastFloor();
      return;
    }

    final scrollable = Scrollable.maybeOf(anchorContext);
    if (scrollable == null) {
      onAtLastFloor();
      return;
    }

    final position = scrollable.position;
    final viewportDimension = position.viewportDimension;
    if (viewportDimension <= 0) {
      onAtLastFloor();
      return;
    }

    // 阅读锚线：视口上方 revealAlignment 处对应的内容坐标。
    final anchorContentY =
        position.pixels + viewportDimension * revealAlignment;

    var currentIndex = -1;
    for (var i = 0; i < postKeys.length; i++) {
      final ctx = postKeys[i].currentContext;
      if (ctx == null) continue;
      final renderObject = ctx.findRenderObject();
      if (renderObject == null) continue;
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) continue;
      final itemTop = viewport.getOffsetToReveal(renderObject, 0).offset;
      if (itemTop <= anchorContentY + 0.5) {
        currentIndex = i;
      }
    }

    if (currentIndex < 0) {
      currentIndex = 0;
    }

    final nextIndex = currentIndex + 1;
    if (nextIndex >= postKeys.length) {
      onAtLastFloor();
      return;
    }

    var nextContext = postKeys[nextIndex].currentContext;
    if (nextContext == null) {
      final currentContext = postKeys[currentIndex].currentContext;
      final currentRender = currentContext?.findRenderObject();
      final currentViewport = currentRender == null
          ? null
          : RenderAbstractViewport.maybeOf(currentRender);
      if (currentRender == null || currentViewport == null) return;

      // 下一楼可能尚未被 ListView.builder 构建。根据当前楼层底边估算下一楼
      // 顶部并滚向该位置，等待布局后再用真实 RenderObject 精确对齐。
      final currentTop =
          currentViewport.getOffsetToReveal(currentRender, 0).offset;
      final estimatedTarget = currentTop +
          currentRender.paintBounds.height -
          viewportDimension * revealAlignment;

      for (var pass = 0; pass < 4 && nextContext == null; pass++) {
        final target = estimatedTarget.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        await position.animateTo(
          target,
          duration: scrollDuration,
          curve: scrollCurve,
        );
        await WidgetsBinding.instance.endOfFrame;
        nextContext = postKeys[nextIndex].currentContext;
      }
      if (nextContext == null) return;
    }

    final nextRender = nextContext.findRenderObject();
    if (nextRender == null) {
      onAtLastFloor();
      return;
    }
    final nextViewport = RenderAbstractViewport.maybeOf(nextRender);
    if (nextViewport == null) {
      onAtLastFloor();
      return;
    }

    // 始终滚到目标对齐位，即使下一楼已在屏内也 reposition。
    final targetScroll = nextViewport
        .getOffsetToReveal(nextRender, revealAlignment)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    position.animateTo(
      targetScroll,
      duration: scrollDuration,
      curve: scrollCurve,
    );
  }
}
