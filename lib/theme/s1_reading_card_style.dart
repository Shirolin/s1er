import 'package:flutter/material.dart';

import '../utils/window_size.dart';
import 'app_theme.dart';

/// Geometry for thread-list / post-floor cards.
///
/// When [enabled] and the window is compact (≤599dp), cards go full-bleed:
/// no side gutter and no corner radius. Wider windows keep the floating card.
abstract final class S1ReadingCardStyle {
  static const double sideMargin = 8;

  static bool isFullBleed(BuildContext context, {required bool enabled}) {
    return enabled && context.windowSize == S1WindowSize.compact;
  }

  static EdgeInsets margin(
    BuildContext context, {
    required bool enabled,
    required double vertical,
  }) {
    return EdgeInsets.symmetric(
      horizontal: isFullBleed(context, enabled: enabled) ? 0 : sideMargin,
      vertical: vertical,
    );
  }

  static BorderRadius inkBorderRadius(
    BuildContext context, {
    required bool enabled,
  }) {
    return isFullBleed(context, enabled: enabled)
        ? BorderRadius.zero
        : S1Shape.medium;
  }

  static ShapeBorder shape(
    BuildContext context, {
    required bool enabled,
    BorderSide side = BorderSide.none,
  }) {
    return RoundedRectangleBorder(
      borderRadius: inkBorderRadius(context, enabled: enabled),
      side: side,
    );
  }
}
