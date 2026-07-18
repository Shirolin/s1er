import 'package:flutter/widgets.dart';

/// 供 [openInternalLocation] 在同帖 `replace` 前抓拍阅读位。
class InThreadJumpCapture extends InheritedWidget {
  const InThreadJumpCapture({
    super.key,
    required this.onCapture,
    required super.child,
  });

  final VoidCallback onCapture;

  static InThreadJumpCapture? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InThreadJumpCapture>();
  }

  /// 不建立依赖，仅在导航前调用一次。
  static void captureIfPresent(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<InThreadJumpCapture>();
    scope?.onCapture();
  }

  @override
  bool updateShouldNotify(InThreadJumpCapture oldWidget) =>
      onCapture != oldWidget.onCapture;
}
