import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// iPadOS / macOS 系统分享面板的 popover 锚点（share_plus 的
/// `sharePositionOrigin`）。
///
/// iPad 上不传锚点时分享面板会因缺少 popover anchor 直接失败。
/// 优先取 [context] 元素的可视区域（锚在触发按钮上）；无 context 时
/// 回退到主视图中心，保证静态入口（如备份导出）同样可用。
Rect systemShareAnchor({BuildContext? context}) {
  if (context != null) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
  }

  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view != null) {
    final logical = view.physicalSize / view.devicePixelRatio;
    const anchorSize = 48.0;
    return Rect.fromLTWH(
      (logical.width - anchorSize) / 2,
      (logical.height - anchorSize) / 2,
      anchorSize,
      anchorSize,
    );
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}
