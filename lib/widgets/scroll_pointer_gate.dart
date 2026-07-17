import 'dart:async';

import 'package:flutter/widgets.dart';

/// 列表滚动期间关闭正文链接命中，减轻链接密集楼层的滑动卡顿。
///
/// 用 [ListenableBuilder] 包住 [IgnorePointer]，避免滚动起停时重建 Html 树。
class ScrollPointerGate extends InheritedNotifier<ValueNotifier<bool>> {
  const ScrollPointerGate({
    super.key,
    required ValueNotifier<bool> scrolling,
    required super.child,
  }) : super(notifier: scrolling);

  /// 不建立依赖，避免滚动起停时重建整棵正文；由 [ScrollAwareIgnorePointer]
  /// 通过 [ListenableBuilder] 只更新 [IgnorePointer]。
  static ValueNotifier<bool>? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ScrollPointerGate>()?.notifier;
  }
}

/// 把 [ScrollNotification] 转成「是否正在滚动」；停止后短暂防抖再恢复命中。
class ScrollPointerGateHost extends StatefulWidget {
  const ScrollPointerGateHost({
    super.key,
    required this.child,
    this.idleDelay = const Duration(milliseconds: 80),
  });

  final Widget child;
  final Duration idleDelay;

  @override
  State<ScrollPointerGateHost> createState() => _ScrollPointerGateHostState();
}

class _ScrollPointerGateHostState extends State<ScrollPointerGateHost> {
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);
  Timer? _idleTimer;

  @override
  void dispose() {
    _idleTimer?.cancel();
    _scrolling.dispose();
    super.dispose();
  }

  void _setScrolling(bool value) {
    if (_scrolling.value == value) return;
    _scrolling.value = value;
  }

  void _onScrollActivity() {
    _idleTimer?.cancel();
    _setScrolling(true);
    _idleTimer = Timer(widget.idleDelay, () => _setScrolling(false));
  }

  bool _onNotification(ScrollNotification notification) {
    // 深度 0：当前列表；忽略内嵌滚动（如引用区）。
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        notification is ScrollStartNotification) {
      _onScrollActivity();
    } else if (notification is ScrollEndNotification) {
      _idleTimer?.cancel();
      _idleTimer = Timer(widget.idleDelay, () => _setScrolling(false));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: ScrollPointerGate(
        scrolling: _scrolling,
        child: widget.child,
      ),
    );
  }
}

/// 滚动中忽略指针；无 Gate 时原样返回 [child]（不订阅、不重建）。
class ScrollAwareIgnorePointer extends StatelessWidget {
  const ScrollAwareIgnorePointer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrolling = ScrollPointerGate.maybeOf(context);
    if (scrolling == null) return child;

    return ListenableBuilder(
      listenable: scrolling,
      builder: (context, child) {
        return IgnorePointer(
          ignoring: scrolling.value,
          child: child,
        );
      },
      child: child,
    );
  }
}
