import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 在子组件进入视口（含预加载边距）时触发 [onVisible]，仅一次。
class LazyVisibilityLoader extends StatefulWidget {
  const LazyVisibilityLoader({
    super.key,
    required this.onVisible,
    required this.child,
    this.preloadMargin = 200,
  });

  final VoidCallback onVisible;
  final Widget child;
  final double preloadMargin;

  @override
  State<LazyVisibilityLoader> createState() => _LazyVisibilityLoaderState();
}

class _LazyVisibilityLoaderState extends State<LazyVisibilityLoader> {
  bool _fired = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_fired || !mounted || _checkScheduled) return;
    _checkScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _checkScheduled = false;
      _checkVisibility();
    });
  }

  bool _intersectsViewport(RenderBox box) {
    if (!box.attached || !box.hasSize) return false;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.sizeOf(context);
    final margin = widget.preloadMargin;
    final rectTop = offset.dy;
    final rectBottom = offset.dy + size.height;
    return rectBottom >= -margin && rectTop <= screen.height + margin;
  }

  void _checkVisibility() {
    if (_fired || !mounted) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return;
    }

    if (!_intersectsViewport(renderObject)) return;

    _fired = true;
    widget.onVisible();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleCheck();
        return false;
      },
      child: widget.child,
    );
  }
}
