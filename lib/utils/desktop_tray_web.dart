import 'dart:async';

import 'package:flutter/foundation.dart';

/// Web stub: the system tray does not exist in a browser.
abstract final class S1DesktopTray {
  static bool? _supportedOverride;

  /// Test hook — when non-null, replaces the platform check.
  @visibleForTesting
  static set supportedOverride(bool? value) => _supportedOverride = value;

  static bool get isSupported => _supportedOverride ?? false;
}

/// Web no-op counterpart of the desktop controller.
class DesktopTrayController {
  DesktopTrayController();

  static DesktopTrayController instance = DesktopTrayController();

  @visibleForTesting
  static set testInstance(DesktopTrayController? value) {
    instance = value ?? DesktopTrayController();
  }

  bool get isInitialized => false;

  bool get closeToTray => false;

  Future<void> initialize({
    required bool closeToTray,
    required bool showIcon,
    required String iconAsset,
  }) async {}

  Future<void> setShowIcon(
    bool show, {
    required bool closeToTray,
    required String iconAsset,
  }) async {}

  Future<void> setCloseToTray(bool value) async {}

  Future<void> setIconAsset(String asset) async {}
}
