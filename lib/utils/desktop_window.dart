import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop-only window chrome helpers (Windows / macOS / Linux).
///
/// Web and mobile leave the OS chrome alone; [isSupported] is false there.
abstract final class S1DesktopWindow {
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

  /// Hides the native title bar. No-op when [isSupported] is false.
  ///
  /// Keeps the runner default size (do not force plugin defaults).
  static Future<void> ensureInitialized() async {
    if (!isSupported) return;
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

/// Injectable façade over [windowManager] so widget tests need no HWND.
class DesktopWindowController {
  const DesktopWindowController();

  static DesktopWindowController instance = const DesktopWindowController();

  @visibleForTesting
  static set testInstance(DesktopWindowController? value) {
    instance = value ?? const DesktopWindowController();
  }

  Future<void> minimize() => windowManager.minimize();

  Future<void> toggleMaximize() async {
    if (await isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> close() => windowManager.close();

  Future<bool> isMaximized() => windowManager.isMaximized();

  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}
