import 'package:flutter/material.dart';

import '../utils/desktop_window.dart';
import 's1_window_title_bar.dart';

/// Wraps [child] with a custom title bar on desktop; pass-through elsewhere.
class S1DesktopWindowFrame extends StatelessWidget {
  const S1DesktopWindowFrame({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;
  final DesktopWindowController? controller;

  @override
  Widget build(BuildContext context) {
    if (!S1DesktopWindow.isSupported) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        S1WindowTitleBar(controller: controller),
        Expanded(child: child),
      ],
    );
  }
}
