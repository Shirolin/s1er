/// 图片查看器变换矩阵的平移钳制（纯函数）。
///
/// 用精确的 min/max 比较替代 `InteractiveViewer` 内部基于 Quad 点积几何的
/// `_exceedsBy` 越界检测——后者在长图等大坐标场景下浮点误差会骗过
/// 9 位小数取整，导致贴边被误判为越界后平移被写 0（跳回图片开头）。
/// 参见 https://github.com/flutter/flutter/issues/191482。
///
/// 规则：
/// - 内容大于视口的轴：平移钳制在 `[viewport - content, 0]`
///   （内容恰好盖满视口的两个极限位置）。
/// - 内容小于等于视口的轴：该轴居中，输入被忽略（min == max）。
///
/// 幂等：处于边界上的输入原样返回，可安全用于同步 listener 反复调用。
///
/// 纯 Dart，不依赖 Flutter。
(double, double) clampImageViewerTranslation({
  required double scale,
  required double viewportWidth,
  required double viewportHeight,
  required double imageWidth,
  required double imageHeight,
  required double tx,
  required double ty,
}) {
  return (
    _clamp(tx, viewportWidth, imageWidth * scale),
    _clamp(ty, viewportHeight, imageHeight * scale),
  );
}

double _clamp(double t, double viewport, double content) {
  if (content <= viewport) {
    // 内容放不下视口或恰好等于视口：居中。
    return (viewport - content) / 2;
  }
  final min = viewport - content; // <= 0
  if (t < min) return min;
  if (t > 0) return 0;
  return t;
}
