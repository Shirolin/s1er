import 'package:flutter/material.dart';

import '../theme/s1_mouse_cursors.dart';

/// [InkWell] that applies S1er's pointer policy by default.
///
/// Flutter 3.44 resets an omitted `mouseCursor` to
/// [WidgetStateMouseCursor.adaptiveClickable], which renders as the plain arrow
/// on desktop. S1er keeps the web-style hand cursor (see
/// `docs/adr/0010-desktop-mouse-cursor-policy.md`), so tappable surfaces go
/// through this widget instead of a raw [InkWell].
///
/// Pass [mouseCursor] only for deliberate exceptions (e.g. a draggable
/// surface); otherwise the hand cursor is inherited.
class S1InkWell extends StatelessWidget {
  const S1InkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.excludeFromSemantics = false,
    this.mouseCursor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool excludeFromSemantics;
  final MouseCursor? mouseCursor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      customBorder: customBorder,
      excludeFromSemantics: excludeFromSemantics,
      mouseCursor: mouseCursor ?? S1MouseCursors.clickable,
      child: child,
    );
  }
}
