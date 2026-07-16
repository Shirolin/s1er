import 'package:flutter/material.dart';

/// Inherited widget that forces image loading in the subtree.
/// Used by share card to override user image settings.
/// Also consumed by [ImageViewer] and [WebAvatar] to bypass policy gates.
class ForceShowImages extends InheritedWidget {
  const ForceShowImages({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ForceShowImages>()
            ?.enabled ??
        false;
  }

  /// Reads the flag without registering a dependency.
  /// Safe to call from [State.initState] or listener callbacks where
  /// `dependOnInheritedWidgetOfExactType` is not allowed.
  static bool read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ForceShowImages>()?.enabled ??
        false;
  }

  @override
  bool updateShouldNotify(ForceShowImages oldWidget) {
    return oldWidget.enabled != enabled;
  }
}
