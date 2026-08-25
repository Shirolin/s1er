import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/boundary_feedback.dart';

/// 单页帖触底后的左滑刷新：未触底不进入手势竞技，避免抢竖读。
class S1TerminalLeftSwipe extends StatefulWidget {
  const S1TerminalLeftSwipe({
    super.key,
    required this.scrollController,
    required this.feedback,
    required this.onRefresh,
    required this.child,
  });

  final ScrollController scrollController;
  final BoundaryFeedbackController feedback;
  final Future<void> Function() onRefresh;
  final Widget child;

  /// 左滑触发刷新的位移阈值。
  static const double swipeThreshold = 48;

  /// 与纵滑触底判定一致的 extent 容差。
  static const double extentSlack = 1;

  @override
  State<S1TerminalLeftSwipe> createState() => _S1TerminalLeftSwipeState();
}

class _S1TerminalLeftSwipeState extends State<S1TerminalLeftSwipe> {
  bool _dispatchedThisGesture = false;
  double _accumulatedDx = 0;

  bool _isAtBottom() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return false;
    for (final position in controller.positions) {
      if (!position.hasPixels || !position.hasContentDimensions) {
        continue;
      }
      if (position.pixels >=
          position.maxScrollExtent - S1TerminalLeftSwipe.extentSlack) {
        return true;
      }
    }
    return false;
  }

  void _resetGesture() {
    _dispatchedThisGesture = false;
    _accumulatedDx = 0;
  }

  void _onStart(DragStartDetails details) {
    _resetGesture();
  }

  void _onUpdate(DragUpdateDetails details) {
    _accumulatedDx += details.delta.dx;
    if (_dispatchedThisGesture) return;
    // 右滑不刷新；需累计向左超过阈值。
    if (_accumulatedDx > -S1TerminalLeftSwipe.swipeThreshold) return;

    final result = widget.feedback.hit(
      context,
      BoundaryEdge.lastPage,
      showMessage: false,
    );
    if (result == BoundaryHitResult.ignored) return;
    _dispatchedThisGesture = true;
    unawaited(widget.onRefresh());
  }

  void _onEnd(DragEndDetails details) => _resetGesture();

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _AtBottomHorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _AtBottomHorizontalDragGestureRecognizer>(
          () => _AtBottomHorizontalDragGestureRecognizer(
            isEnabled: _isAtBottom,
            debugOwner: this,
          ),
          (recognizer) {
            recognizer
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
              ..onStart = _onStart
              ..onUpdate = _onUpdate
              ..onEnd = _onEnd
              ..onCancel = _resetGesture;
          },
        ),
      },
      child: widget.child,
    );
  }
}

/// 仅在列表已触底时加入横向拖动手势竞技。
class _AtBottomHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  _AtBottomHorizontalDragGestureRecognizer({
    required this.isEnabled,
    super.debugOwner,
  });

  final ValueGetter<bool> isEnabled;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!isEnabled()) return;
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    if (!isEnabled()) return;
    super.addAllowedPointerPanZoom(event);
  }
}
