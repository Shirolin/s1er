import 'package:flutter/material.dart';

import '../utils/window_size.dart';

/// Design tokens for adaptive sheet content. Prefer [S1AdaptiveSheetInsets.of]
/// over hard-coded padding in sheet builders.
abstract final class S1AdaptiveSheetSpec {
  static const double actionMenuWidth = 400;
  static const double formWidth = 640;
  static const double pickerWidth = 480;
  static const double infoWidth = 560;
  static const double profileWidth = 400;

  static const double defaultMaxHeightFactor = 0.85;
  static const double pickerMaxHeightFactor = 0.65;

  static const EdgeInsets compactContentPadding =
      EdgeInsets.fromLTRB(16, 0, 16, 8);
  static const EdgeInsets desktopContentPadding = EdgeInsets.all(24);

  static EdgeInsets contentPadding(BuildContext context) =>
      context.isExpandedOrAbove ? desktopContentPadding : compactContentPadding;

  static TextStyle? titleStyle(
    BuildContext context, {
    bool prominent = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = context.isExpandedOrAbove;
    if (prominent && !isDesktop) {
      return textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    }
    return (isDesktop ? textTheme.titleMedium : textTheme.titleSmall)?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
  }

  static TextStyle? subtitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
  }
}

/// Adaptive content insets including keyboard / safe-area bottom.
class S1AdaptiveSheetInsets {
  const S1AdaptiveSheetInsets._({
    required this.content,
    required this.bottomInset,
  });

  final EdgeInsets content;
  final double bottomInset;

  static S1AdaptiveSheetInsets of(BuildContext context) {
    final base = S1AdaptiveSheetSpec.contentPadding(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return S1AdaptiveSheetInsets._(
      content: base.copyWith(bottom: base.bottom + bottomInset),
      bottomInset: bottomInset,
    );
  }
}
