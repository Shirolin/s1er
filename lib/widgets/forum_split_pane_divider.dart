import 'package:flutter/material.dart';

/// Vertical divider with a draggable resize handle between forum list/detail panes.
class ForumSplitPaneDivider extends StatelessWidget {
  const ForumSplitPaneDivider({
    super.key,
    required this.onDragDelta,
  });

  final ValueChanged<double> onDragDelta;

  static const double hitWidth = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: hitWidth,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Center(
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
          ),
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  onDragDelta(details.delta.dx);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
