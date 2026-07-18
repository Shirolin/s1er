import 'package:flutter/material.dart';

/// MD3 Window size classes based on Material Design 3 canonical layout
/// breakpoints.
///
/// See: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum S1WindowSize {
  /// 0–599dp — phone-sized screens
  compact,

  /// 600–839dp — tablet portrait, small desktop
  medium,

  /// 840–1199dp — tablet landscape, typical desktop
  expanded,

  /// 1200–1599dp — large desktop
  large,

  /// 1600dp+ — extra-large desktop
  extraLarge;
}

/// MD3 canonical breakpoint constants.
abstract class S1Breakpoints {
  S1Breakpoints._();

  static const double compactMax = 599;
  static const double mediumMax = 839;
  static const double expandedMax = 1199;
  static const double largeMax = 1599;

  /// Max content width for Expanded windows (840dp–1199dp).
  static const double contentWidthExpanded = 840;

  /// Max content width for Large+ windows (1200dp+).
  static const double contentWidthLarge = 1040;

  /// Max content width for focused form workflows.
  static const double contentWidthForm = 720;

  /// Max content width for long-form reading (thread detail).
  ///
  /// Narrower than [contentWidthExpanded] so body line length stays closer to
  /// a comfortable reading measure on desktop; still wider than Apple's ~672
  /// readable guide to leave room for post chrome (avatar row, poll, cards).
  static const double contentWidthReading = 720;
}

extension S1WindowSizeX on BuildContext {
  /// Returns the current [S1WindowSize] based on horizontal screen size.
  ///
  /// Uses [MediaQuery.sizeOf] for efficiency. When this getter is called
  /// inside the build method it re-evaluates on every resize automatically.
  S1WindowSize get windowSize {
    final width = MediaQuery.sizeOf(this).width;
    return width.toWindowSize();
  }

  /// Whether the screen is at least Medium (>= 600dp).
  bool get isMediumOrAbove => windowSize.index >= S1WindowSize.medium.index;

  /// Whether the screen is at least Expanded (>= 840dp).
  bool get isExpandedOrAbove => windowSize.index >= S1WindowSize.expanded.index;

  /// Whether the screen is at least Large (>= 1200dp).
  bool get isLargeOrAbove => windowSize.index >= S1WindowSize.large.index;
}

extension S1WindowSizeNumX on double {
  S1WindowSize toWindowSize() {
    if (this <= S1Breakpoints.compactMax) return S1WindowSize.compact;
    if (this <= S1Breakpoints.mediumMax) return S1WindowSize.medium;
    if (this <= S1Breakpoints.expandedMax) return S1WindowSize.expanded;
    if (this <= S1Breakpoints.largeMax) return S1WindowSize.large;
    return S1WindowSize.extraLarge;
  }
}

/// Adaptive builder that calls different widget builders based on window width.
///
/// This is a screen-level adaptive widget. It uses [LayoutBuilder] internally
/// so the sizing is relative to the parent's constraints, not the full screen.
/// Pass [buildCompact] for Compact (< 600dp), [buildMedium] for Medium
/// (600–839dp), and [buildWide] for Expanded+ (>= 840dp).
///
/// Example:
/// ```dart
/// S1AdaptiveBuilder(
///   buildCompact: (context) => NavigationBar(...),
///   buildMedium: (context) => NavigationRail(...),
///   buildWide: (context) => Row(children: [sidePanel, mainContent]),
/// )
/// ```
class S1AdaptiveBuilder extends StatelessWidget {
  const S1AdaptiveBuilder({
    super.key,
    this.buildCompact,
    this.buildMedium,
    required this.buildWide,
  });

  /// Builder for Compact size class (< 600dp).
  final WidgetBuilder? buildCompact;

  /// Builder for Medium size class (600–839dp).
  final WidgetBuilder? buildMedium;

  /// Builder for Expanded+ size classes (>= 840dp).
  final WidgetBuilder buildWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.toWindowSize();
        return switch (size) {
          S1WindowSize.compact =>
            buildCompact?.call(context) ?? buildWide(context),
          S1WindowSize.medium =>
            buildMedium?.call(context) ?? buildWide(context),
          S1WindowSize.expanded ||
          S1WindowSize.large ||
          S1WindowSize.extraLarge =>
            buildWide(context),
        };
      },
    );
  }
}
