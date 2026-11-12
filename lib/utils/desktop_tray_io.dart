import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../config/constants.dart';
import '../services/talker.dart';
import 'app_messenger.dart';

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
  MenuItem? _toggleItem;
  bool _closeToTray = false;
  bool _initialized = false;
  bool _trayHintShown = false;

  bool get isInitialized => _initialized;

  bool get closeToTray => _closeToTray;

  /// Loads [asset] into memory as a native image.
  ///
  /// `ImageAsset.fromAsset` passes the bundled file's *path* to the native
  /// side, and GDI+ keeps that file open for the image's lifetime. That handle
  /// makes the Windows overlay updater fail to rename
  /// `data/flutter_assets/…` and roll the whole update back. Decoding the
  /// bytes here keeps the asset off the filesystem entirely.
  static Future<Image?> _loadTrayImage(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return Image.fromBase64('data:image/png;base64,${base64Encode(bytes)}');
  }

  /// Creates the tray icon and applies the saved close behaviour.
  ///
  /// When [showIcon] is false no icon is created (or an existing one is
  /// removed). Failures are logged and leave the app fully usable: the window
  /// keeps its normal close behaviour instead of trapping the user without a
  /// tray icon.
  Future<void> initialize({
    required bool closeToTray,
    required bool showIcon,
    required String iconAsset,
  }) async {
    if (!S1DesktopTray.isSupported) return;
    if (!showIcon) {
      await _teardown();
      return;
    }
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

      image = await _loadTrayImage(iconAsset);
      if (image == null) {
        throw StateError('Tray icon asset not found: $iconAsset');
      }
      icon.icon = image;
      icon.isIconTemplate = false;
      icon.setTooltip(S1Constants.appName);

      _toggleItem = _addMenuItem(
        menu,
        items,
        listenerIds,
        '隐藏到托盘',
        _toggleWindow,
      );
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
      await _resetPreventClose();
    }
  }

  /// Shows or hides the tray icon (设置 → 桌面).
  Future<void> setShowIcon(
    bool show, {
    required bool closeToTray,
    required String iconAsset,
  }) async {
    if (!S1DesktopTray.isSupported) return;
    await initialize(
      closeToTray: closeToTray,
      showIcon: show,
      iconAsset: iconAsset,
    );
  }

  /// Removes the tray icon, its menu and the window listener, and stops
  /// intercepting the close button.
  Future<void> _teardown() async {
    final icon = _icon;
    final menu = _menu;
    final image = _image;
    final trayListenerId = _trayListenerId;
    final items = List<MenuItem>.of(_menuItems);
    final listenerIds = List<ListenerId>.of(_menuListenerIds);

    _icon = null;
    _image = null;
    _menu = null;
    _menuItems.clear();
    _menuListenerIds.clear();
    _trayListenerId = null;
    _toggleItem = null;
    _closeToTray = false;
    _initialized = false;

    try {
      windowManager.removeListener(this);
    } on Object catch (e, st) {
      talker.handle(e, st, 'Desktop tray removeListener failed');
    }
    if (icon != null) {
      if (trayListenerId != null) {
        icon.removeListener(trayListenerId);
      }
      icon.dispose();
    }
    menu?.dispose();
    for (var i = 0; i < items.length; i++) {
      if (i < listenerIds.length) {
        items[i].removeListener(listenerIds[i]);
      }
      items[i].dispose();
    }
    image?.dispose();
    await _resetPreventClose();
  }

  Future<void> _resetPreventClose() async {
    try {
      await windowManager.setPreventClose(false);
    } on Object catch (e, st) {
      talker.handle(e, st, 'Desktop tray reset preventClose failed');
    }
  }

  MenuItem? _addMenuItem(
    Menu menu,
    List<MenuItem> items,
    List<ListenerId> listenerIds,
    String label,
    Future<void> Function() action,
  ) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
    if (item == null) return null;
    final listenerId = item.addListener((event) {
      if (event is MenuItemClickedEvent) {
        unawaited(action());
      }
    });
    menu.addItem(item);
    items.add(item);
    listenerIds.add(listenerId);
    return item;
  }

  /// Switches the tray image to [asset] (already themed).
  Future<void> setIconAsset(String asset) async {
    if (!_initialized) return;
    final icon = _icon;
    if (icon == null) return;
    try {
      final image = await _loadTrayImage(asset);
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
    // No tray icon means no way back from a hidden window.
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
    unawaited(_hideToTray());
  }

  /// Hides the window to the tray. The first close of a session briefly says
  /// where the window went, so the app does not look like it vanished.
  Future<void> _hideToTray() async {
    if (!_trayHintShown) {
      _trayHintShown = true;
      final messenger = s1MessengerKey.currentState;
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                '${S1Constants.appName} 仍在系统托盘运行，单击托盘图标可重新打开。',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1600),
            ),
          );
        // Let the hint be read before the window goes away.
        await Future<void>.delayed(const Duration(milliseconds: 1400));
      }
    }
    await windowManager.hide();
    await _refreshToggleLabel();
  }

  void _onTrayEvent(TrayIconEvent event) {
    if (event is TrayIconClickedEvent) {
      unawaited(_toggleWindow());
    }
  }

  Future<void> _showWindow() async {
    // show() restores a minimized window first.
    await windowManager.show();
    await windowManager.focus();
    await _refreshToggleLabel();
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
    await _refreshToggleLabel();
  }

  Future<void> _toggleWindow() async {
    // A minimized window still reports as visible; clicking the tray icon has
    // to bring it back instead of hiding it.
    if (await windowManager.isVisible() && !await windowManager.isMinimized()) {
      await _hideWindow();
    } else {
      await _showWindow();
    }
  }

  /// Keeps the menu label in step with the window ("隐藏到托盘" / "显示 …").
  Future<void> _refreshToggleLabel() async {
    final item = _toggleItem;
    if (item == null) return;
    try {
      final visible = await windowManager.isVisible();
      item.label = visible ? '隐藏到托盘' : '显示 ${S1Constants.appName}';
    } on Object catch (e, st) {
      talker.handle(e, st, 'Desktop tray menu label failed');
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
