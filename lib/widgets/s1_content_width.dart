import 'package:flutter/material.dart';
import '../utils/window_size.dart';

/// Constrains content width on wide screens per MD3 canonical layout.
///
/// - Compact / Medium (< 840dp): passes child through unchanged (full width).
/// - Expanded (840–1199dp): centers child within a max width of 840dp.
/// - Large+ (>= 1200dp): centers child within a max width of 1040dp.
///
/// Usage:
/// ```dart
/// S1ContentWidth(child: ListView(...))
/// ```
class S1ContentWidth extends StatelessWidget {
  const S1ContentWidth({
    super.key,
    required this.child,
  });

  /// The child widget to constrain.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.isExpandedOrAbove) {
      return child;
    }

    final maxWidth = context.windowSize == S1WindowSize.expanded
        ? S1Breakpoints.contentWidthExpanded
        : S1Breakpoints.contentWidthLarge;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
