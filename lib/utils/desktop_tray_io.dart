import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../config/constants.dart';
import '../services/talker.dart';

/// Desktop-only system tray support (Windows / macOS / Linux).
///
/// [S1DesktopTray.isSupported] is false on Web and mobile so callers can keep
/// tray wiring out of those platforms entirely.
abstract final class S1DesktopTray {
  static bool? _supportedOverride;

  /// Test hook — when non-null, replaces the platform check.
  @visibleForTesting
  static set supportedOverride(bool? value) => _supportedOverride = value;

  static bool get isSupported {
    if (_supportedOverride != null) return _supportedOverride!;
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }
}

/// Owns the tray icon, its menu, and the window-visibility actions behind it.
///
/// The close button hides the window instead of quitting when [closeToTray] is
/// on; quitting is always available from the tray menu.
class DesktopTrayController with WindowListener {
  DesktopTrayController();

  static DesktopTrayController instance = DesktopTrayController();

  @visibleForTesting
  static set testInstance(DesktopTrayController? value) {
    instance = value ?? DesktopTrayController();
  }

  // Retained so the native handles outlive menu callbacks; dropping them lets
  // the FFI finalizers free the handles while the menu is still on screen.
  TrayIcon? _icon;
  Image? _image;
  // ignore: unused_field
  Menu? _menu;
  final List<MenuItem> _menuItems = <MenuItem>[];
  final List<ListenerId> _menuListenerIds = <ListenerId>[];
  ListenerId? _trayListenerId;
  bool _closeToTray = false;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  bool get closeToTray => _closeToTray;

  /// Creates the tray icon and applies the saved close behaviour.
  ///
  /// Failures are logged and leave the app fully usable: the window keeps its
  /// normal close behaviour instead of trapping the user without a tray icon.
  Future<void> initialize({
    required bool closeToTray,
    required String iconAsset,
  }) async {
    if (!S1DesktopTray.isSupported) return;
    _closeToTray = closeToTray;
    if (_initialized) {
      await setCloseToTray(closeToTray);
      await setIconAsset(iconAsset);
      return;
    }

    TrayIcon? icon;
    Image? image;
    Menu? menu;
    final items = <MenuItem>[];
    final listenerIds = <ListenerId>[];
    var listeningForWindow = false;
    try {
      await windowManager.setPreventClose(closeToTray);

      icon = TrayIcon.create();
      menu = Menu.create();
      if (icon == null || menu == null) {
        throw StateError('Unable to create the system tray icon');
      }

      image = ImageAsset.fromAsset(iconAsset);
      if (image == null) {
        throw StateError('Tray icon asset not found: $iconAsset');
      }
      icon.icon = image;
      icon.isIconTemplate = false;
      icon.setTooltip(S1Constants.appName);

      _addMenuItem(
        menu,
        items,
        listenerIds,
        '显示 ${S1Constants.appName}',
        _showWindow,
      );
      _addMenuItem(menu, items, listenerIds, '隐藏到托盘', _hideWindow);
      menu.addSeparator();
      _addMenuItem(menu, items, listenerIds, '退出', _quit);

      icon.setContextMenu(menu);
      // The native default is "no automatic menu"; open it on right click.
      icon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
      icon.setVisible(true);
      _trayListenerId = icon.addListener(_onTrayEvent);

      windowManager.addListener(this);
      listeningForWindow = true;

      _icon = icon;
      _image = image;
      _menu = menu;
      _menuItems
        ..clear()
        ..addAll(items);
      _menuListenerIds
        ..clear()
        ..addAll(listenerIds);
      _initialized = true;
    } on Object catch (e, st) {
      talker.handle(e, st, 'Desktop tray init failed');
      if (listeningForWindow) {
        windowManager.removeListener(this);
      }
      final trayListenerId = _trayListenerId;
      if (icon != null && trayListenerId != null) {
        icon.removeListener(trayListenerId);
      }
      _trayListenerId = null;
      icon?.dispose();
      menu?.dispose();
      for (var i = 0; i < items.length; i++) {
        if (i < listenerIds.length) {
          items[i].removeListener(listenerIds[i]);
        }
        items[i].dispose();
      }
      image?.dispose();
      // Never leave preventClose armed without a tray icon to reopen from.
      try {
        await windowManager.setPreventClose(false);
      } on Object catch (e, st) {
        talker.handle(e, st, 'Desktop tray reset preventClose failed');
      }
    }
  }

  void _addMenuItem(
    Menu menu,
    List<MenuItem> items,
    List<ListenerId> listenerIds,
    String label,
    Future<void> Function() action,
  ) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
    if (item == null) return;
    final listenerId = item.addListener((event) {
      if (event is MenuItemClickedEvent) {
        unawaited(action());
      }
    });
    menu.addItem(item);
    items.add(item);
    listenerIds.add(listenerId);
  }

  /// Switches the tray image to [asset] (already themed).
  Future<void> setIconAsset(String asset) async {
    if (!_initialized) return;
    final icon = _icon;
    if (icon == null) return;
    try {
      final image = ImageAsset.fromAsset(asset);
      if (image == null) {
        throw StateError('Tray icon asset not found: $asset');
      }
      icon.icon = image;
      _image?.dispose();
      _image = image;
    } on Object catch (e, st) {
      talker.handle(e, st, 'Desktop tray setIconAsset($asset) failed');
    }
  }

  /// Updates whether the window close button hides the app instead of quitting.
  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    if (!_initialized) return;
    try {
      await windowManager.setPreventClose(value);
    } on Object catch (e, st) {
      talker.handle(e, st, 'Desktop tray setPreventClose($value) failed');
    }
  }

  @override
  void onWindowClose() {
    if (!_closeToTray) return;
    unawaited(windowManager.hide());
  }

  void _onTrayEvent(TrayIconEvent event) {
    if (event is TrayIconClickedEvent) {
      unawaited(_toggleWindow());
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideWindow() => windowManager.hide();

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await _hideWindow();
    } else {
      await _showWindow();
    }
  }

  Future<void> _quit() async {
    // Stop intercepting close so a WM_CLOSE during teardown goes through, then
    // get the app off the screen immediately: the menu callback and the engine
    // shutdown each take a few frames, and nothing should stay visible while
    // they run.
    _closeToTray = false;
    // Hide the tray icon instead of disposing it: this callback runs while the
    // menu's native modal loop is still unwinding, and freeing the icon's
    // handles there can trip the native side. Hiding removes it from the tray
    // immediately, which is all quitting needs.
    _icon?.setVisible(false);
    unawaited(windowManager.hide());
    // destroy() posts WM_QUIT directly instead of going through WM_CLOSE, so
    // the preventClose flag does not apply. Awaiting setPreventClose(false)
    // first only added a platform-channel round trip in front of the quit.
    await windowManager.destroy();
  }
}
