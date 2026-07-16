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

  @override
  bool updateShouldNotify(ForceShowImages oldWidget) {
    return oldWidget.enabled != enabled;
  }
}
