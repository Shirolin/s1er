import 'package:flutter/widgets.dart';

/// Clickable region without Material splash; shows hand cursor on desktop/web.
class S1ClickRegion extends StatelessWidget {
  const S1ClickRegion({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior? behavior;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null && onLongPress == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: behavior,
        child: child,
      ),
    );
  }
}
