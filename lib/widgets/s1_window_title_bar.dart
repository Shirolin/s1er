import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../config/constants.dart';
import '../utils/desktop_window.dart';
import '../theme/app_theme.dart';

/// Custom desktop title bar (drag / double-click maximize / window buttons).
///
/// Only used when [S1DesktopWindow.isSupported] is true. Colors follow
/// [S1Surface.page] so the bar matches the app canvas.
class S1WindowTitleBar extends StatefulWidget {
  const S1WindowTitleBar({
    super.key,
    this.controller,
  });

  final DesktopWindowController? controller;

  static const double height = 40;

  @override
  State<S1WindowTitleBar> createState() => _S1WindowTitleBarState();
}

class _S1WindowTitleBarState extends State<S1WindowTitleBar>
    with WindowListener {
  late final DesktopWindowController _controller;
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? DesktopWindowController.instance;
    _controller.addListener(this);
    _refreshMaximized();
  }

  @override
  void dispose() {
    _controller.removeListener(this);
    super.dispose();
  }

  Future<void> _refreshMaximized() async {
    final maximized = await _controller.isMaximized();
    if (!mounted || maximized == _maximized) return;
    setState(() => _maximized = maximized);
  }

  @override
  void onWindowMaximize() {
    if (!_maximized) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (_maximized) setState(() => _maximized = false);
  }

  Future<void> _toggleMaximize() async {
    await _controller.toggleMaximize();
    await _refreshMaximized();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = S1Surface.page(scheme);

    return Material(
      color: background,
      child: SizedBox(
        height: S1WindowTitleBar.height,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Image.asset(
              'assets/branding/s1er_mark.png',
              width: 18,
              height: 18,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 8),
            Text(
              S1Constants.appName,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _toggleMaximize,
                child: const DragToMoveArea(
                  child: SizedBox.expand(),
                ),
              ),
            ),
            _WindowButton(
              tooltip: '最小化',
              icon: Icons.remove,
              onPressed: _controller.minimize,
            ),
            _WindowButton(
              tooltip: _maximized ? '还原' : '最大化',
              icon: _maximized ? Icons.fullscreen_exit : Icons.crop_square,
              onPressed: _toggleMaximize,
            ),
            _WindowButton(
              tooltip: '关闭',
              icon: Icons.close,
              isClose: true,
              onPressed: _controller.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    if (!_hovered) {
      background = Colors.transparent;
      foreground = scheme.onSurfaceVariant;
    } else if (widget.isClose) {
      background = scheme.error;
      foreground = scheme.onError;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurface;
    }

    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPressed(),
          child: AnimatedContainer(
            duration: S1Motion.rapid,
            curve: S1Motion.standard,
            width: 46,
            height: S1WindowTitleBar.height,
            color: background,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}
