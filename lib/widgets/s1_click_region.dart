import 'package:flutter/widgets.dart';

import '../theme/s1_haptics.dart';

/// Clickable region without Material splash; shows hand cursor on desktop/web.
class S1ClickRegion extends StatelessWidget {
  const S1ClickRegion({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior? behavior;

  /// When true (default), tap fires [S1Haptics.selection] and long-press
  /// fires [S1Haptics.medium].
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final tap = haptic ? S1Haptics.wrapTap(onTap) : onTap;
    final longPress =
        haptic ? S1Haptics.wrapLongPress(onLongPress) : onLongPress;
    return MouseRegion(
      cursor: onTap == null && onLongPress == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: tap,
        onLongPress: longPress,
        behavior: behavior,
        child: child,
      ),
    );
  }
}
