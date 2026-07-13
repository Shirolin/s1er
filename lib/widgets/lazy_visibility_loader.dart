import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_checkVisibility);
  }

  bool _intersectsViewport(RenderBox box) {
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.sizeOf(context);
    final margin = widget.preloadMargin;
    final rectTop = offset.dy;
    final rectBottom = offset.dy + size.height;
    return rectBottom >= -margin && rectTop <= screen.height + margin;
  }

  void _checkVisibility([Duration? _]) {
    if (_fired || !mounted) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback(_checkVisibility);
      return;
    }

    if (_intersectsViewport(renderObject)) {
      _fired = true;
      widget.onVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _checkVisibility();
        return false;
      },
      child: widget.child,
    );
  }
}
