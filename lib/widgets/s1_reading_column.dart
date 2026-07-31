import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/window_size.dart';

/// Geometry of the centered reading column inside a parent pane.
class ReadingColumnGeometry {
  const ReadingColumnGeometry({
    required this.columnWidth,
    required this.horizontalInset,
  });

  /// Width of the reading column (≤ [S1Breakpoints.contentWidthReading]).
  final double columnWidth;

  /// Left/right gutter inside the parent: `(parentWidth - columnWidth) / 2`.
  final double horizontalInset;
}

/// Exposes [ReadingColumnGeometry] to descendants (FAB / pagination alignment).
class ReadingColumnScope extends InheritedWidget {
  const ReadingColumnScope({
    super.key,
    required this.geometry,
    required super.child,
  });

  final ReadingColumnGeometry geometry;

  static ReadingColumnGeometry? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReadingColumnScope>()
        ?.geometry;
  }

  @override
  bool updateShouldNotify(ReadingColumnScope oldWidget) {
    return geometry.columnWidth != oldWidget.geometry.columnWidth ||
        geometry.horizontalInset != oldWidget.geometry.horizontalInset;
  }
}

/// Centers a 720dp reading column and publishes its geometry for chrome alignment.
///
/// Unlike [S1ContentWidth], this always constrains width (even when the parent is
/// narrower than 840dp) so embedded forum detail panes keep a stable reading measure.
class S1ReadingColumn extends StatelessWidget {
  const S1ReadingColumn({
    super.key,
    required this.child,
    this.showPaneGutter = false,
  });

  final Widget child;

  /// When true, paints subtle side gutters and [S1Surface.page] behind the
  /// reading column so post cards keep contrast.
  final bool showPaneGutter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        const maxWidth = S1Breakpoints.contentWidthReading;
        final columnWidth =
            maxWidth.clamp(0.0, constraints.maxWidth).toDouble();
        final horizontalInset = ((constraints.maxWidth - columnWidth) / 2)
            .clamp(0.0, double.infinity);
        final height =
            constraints.hasBoundedHeight ? constraints.maxHeight : null;
        final geometry = ReadingColumnGeometry(
          columnWidth: columnWidth,
          horizontalInset: horizontalInset,
        );
        final columnChild = showPaneGutter
            ? ColoredBox(
                color: S1Surface.page(scheme),
                child: child,
              )
            : child;
        final column = ReadingColumnScope(
          geometry: geometry,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: columnWidth,
              height: height,
              child: columnChild,
            ),
          ),
        );
        if (!showPaneGutter || horizontalInset <= 0) return column;
        final gutterColor = scheme.surfaceContainer;
        return Stack(
          fit: StackFit.expand,
          children: [
            column,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: horizontalInset,
              child: ColoredBox(color: gutterColor),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: horizontalInset,
              child: ColoredBox(color: gutterColor),
            ),
          ],
        );
      },
    );
  }
}

/// Horizontally centers [child] to the reading column when [ReadingColumnScope]
/// is present; otherwise stretches full width.
class ReadingColumnAlign extends StatelessWidget {
  const ReadingColumnAlign({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geometry = ReadingColumnScope.maybeOf(context);
    if (geometry == null) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: geometry.columnWidth,
        child: child,
      ),
    );
  }
}
