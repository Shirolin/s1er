import 'package:flutter/widgets.dart';

/// Desktop/web clickable cursor policy for S1er.
///
/// Flutter Material defaults to [WidgetStateMouseCursor.adaptiveClickable]
/// (hand on web only; arrow on Windows / macOS / Linux). S1er follows the
/// web convention: hand cursor on interactive controls via Theme.
///
/// See Flutter issue #182466 / PR #171796.
abstract final class S1MouseCursors {
  /// Hand when enabled; arrow when disabled. All platforms.
  static const WidgetStateMouseCursor clickable =
      WidgetStateMouseCursor.clickable;
}
