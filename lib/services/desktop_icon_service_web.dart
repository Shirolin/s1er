import 'package:flutter/foundation.dart';

import '../models/desktop_shortcut.dart';

export '../models/desktop_shortcut.dart';

/// Web stub: desktop icons and shortcuts do not exist in a browser.
class DesktopIconService {
  DesktopIconService();

  static DesktopIconService instance = DesktopIconService();

  @visibleForTesting
  static set testInstance(DesktopIconService? value) {
    instance = value ?? DesktopIconService();
  }

  static bool? _supportedOverride;

  @visibleForTesting
  static set supportedOverride(bool? value) => _supportedOverride = value;

  static bool get isSupported => _supportedOverride ?? false;

  static const shortcutFileName = 'S1er.lnk';

  Future<bool> apply(String iconId) async => false;

  Future<DesktopShortcutStatus> shortcutStatus() async =>
      DesktopShortcutStatus.missing;

  Future<DesktopShortcutResult> createShortcut(String iconId) async =>
      DesktopShortcutResult.unsupported;

  Future<DesktopShortcutResult> removeShortcut() async =>
      DesktopShortcutResult.unsupported;
}
