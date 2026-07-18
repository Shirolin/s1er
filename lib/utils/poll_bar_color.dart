import 'package:flutter/material.dart';

import 'color_contrast.dart';

/// 解析投票 API 下发的 `#RRGGBB` / `RRGGBB` 十六进制色。
Color? parsePollHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// 投票进度条颜色：优先 API 原色；对比度不足时回退 [ColorScheme.primary]。
Color pollBarColor(String hex, ColorScheme scheme) {
  final apiColor = parsePollHexColor(hex);
  final track = scheme.surfaceContainerHighest;
  if (apiColor != null && ColorContrast.meetsNonTextContrast(apiColor, track)) {
    return apiColor;
  }
  return scheme.primary;
}
