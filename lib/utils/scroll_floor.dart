import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'scroll_motion.dart';

/// 帖子详情「下一楼」滚动：定位当前阅读楼并滚至下一楼靠上展示。
abstract class ScrollFloorNavigator {
  /// 下一楼目标在视口中的纵向对齐（靠上阅读区）。
  static const double revealAlignment = 0.08;

  /// 已对齐时跳过微动画，避免连点抖动。
  static const double alignSkipTolerance = 16;

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
      if (renderObject == null || !renderObject.attached) continue;
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
      if (currentRender == null || !currentRender.attached) return;
      final currentViewport = RenderAbstractViewport.maybeOf(currentRender);
      if (currentViewport == null) return;

      // 下一楼可能尚未被 ListView.builder 构建：先一次主滚拉入视口，再静默校正。
      final currentTop =
          currentViewport.getOffsetToReveal(currentRender, 0).offset;
      final estimatedTarget = currentTop +
          currentRender.paintBounds.height -
          viewportDimension * revealAlignment;

      final revealTarget = estimatedTarget.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      await S1ScrollMotion.animateTo(position, revealTarget);
      await WidgetsBinding.instance.endOfFrame;
      nextContext = postKeys[nextIndex].currentContext;

      if (nextContext == null) {
        await S1ScrollMotion.correctSilentlyIfNeeded(position, revealTarget);
        await WidgetsBinding.instance.endOfFrame;
        nextContext = postKeys[nextIndex].currentContext;
      }
      if (nextContext == null) return;
    }

    final nextRender = postKeys[nextIndex].currentContext?.findRenderObject();
    if (nextRender == null || !nextRender.attached) return;
    final nextViewport = RenderAbstractViewport.maybeOf(nextRender);
    if (nextViewport == null) return;

    final targetScroll = nextViewport
        .getOffsetToReveal(nextRender, revealAlignment)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    final delta = (targetScroll - position.pixels).abs();
    if (delta <= alignSkipTolerance) return;

    await S1ScrollMotion.animateTo(position, targetScroll);
  }

  /// 将 [postKeys] 中 [index] 对应楼滚至 [revealAlignment]。
  ///
  /// 目标尚未被懒列表构建时：先估算滚动拉入视口，再校正。
  static Future<bool> scrollToIndex({
    required List<GlobalKey> postKeys,
    required int index,
    double alignment = revealAlignment,
  }) async {
    if (postKeys.isEmpty || index < 0 || index >= postKeys.length) {
      return false;
    }

    BuildContext? anchorContext;
    for (final key in postKeys) {
      if (key.currentContext != null) {
        anchorContext = key.currentContext;
        break;
      }
    }
    // 全未构建：尝试用 index 0 的 key 所在 Scrollable 不可用时，直接失败由调用方重试。
    anchorContext ??= postKeys[index].currentContext;
    if (anchorContext == null) {
      // 强制触发离屏项：找任一已附着的 Scrollable（经 postKeys 外部传入的 ancestor）。
      return false;
    }

    final scrollable = Scrollable.maybeOf(anchorContext);
    if (scrollable == null) return false;

    final position = scrollable.position;
    final viewportDimension = position.viewportDimension;
    if (viewportDimension <= 0) return false;

    var targetContext = postKeys[index].currentContext;
    if (targetContext == null) {
      // 估算：按近似行高推进到目标附近。
      final estimated =
          (position.pixels + index * viewportDimension * 0.45).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      await S1ScrollMotion.animateTo(position, estimated);
      await WidgetsBinding.instance.endOfFrame;
      targetContext = postKeys[index].currentContext;
      if (targetContext == null) {
        await S1ScrollMotion.correctSilentlyIfNeeded(position, estimated);
        await WidgetsBinding.instance.endOfFrame;
        targetContext = postKeys[index].currentContext;
      }
      if (targetContext == null) return false;
    }

    if (!targetContext.mounted) return false;
    final render = targetContext.findRenderObject();
    if (render == null || !render.attached) return false;
    final viewport = RenderAbstractViewport.maybeOf(render);
    if (viewport == null) return false;

    final targetScroll = viewport
        .getOffsetToReveal(render, alignment)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    final delta = (targetScroll - position.pixels).abs();
    if (delta > alignSkipTolerance) {
      await S1ScrollMotion.animateTo(position, targetScroll);
    }
    return true;
  }

  /// 根据 [_postKeys] 与视口，解析当前“靠上可见”的页内楼层索引（0-based）。
  static int? findLeadingVisiblePostIndex({
    required List<GlobalKey> postKeys,
  }) {
    if (postKeys.isEmpty) return null;

    BuildContext? anchorContext;
    for (final key in postKeys) {
      if (key.currentContext != null) {
        anchorContext = key.currentContext;
        break;
      }
    }
    if (anchorContext == null) return null;

    final scrollable = Scrollable.maybeOf(anchorContext);
    if (scrollable == null) return null;
    final position = scrollable.position;
    final viewportDimension = position.viewportDimension;
    if (viewportDimension <= 0) return null;

    final anchorContentY =
        position.pixels + viewportDimension * revealAlignment;

    var currentIndex = -1;
    for (var i = 0; i < postKeys.length; i++) {
      final ctx = postKeys[i].currentContext;
      if (ctx == null) continue;
      final renderObject = ctx.findRenderObject();
      if (renderObject == null || !renderObject.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) continue;
      final itemTop = viewport.getOffsetToReveal(renderObject, 0).offset;
      if (itemTop <= anchorContentY + 0.5) {
        currentIndex = i;
      }
    }
    if (currentIndex < 0) return 0;
    return currentIndex;
  }
}
