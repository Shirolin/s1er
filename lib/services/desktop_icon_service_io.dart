import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';

import '../config/app_icon_catalog.dart';
import '../config/constants.dart';
import '../models/desktop_shortcut.dart';
import 'talker.dart';
import 'windows_icon_ico.dart';

export '../models/desktop_shortcut.dart';

/// Desktop icon identity on Windows: window/taskbar icon, generated `.ico`,
/// and the desktop shortcut.
///
/// The executable's own file icon is embedded in its PE resources and cannot
/// be changed at runtime; only shortcuts created by this service point at the
/// per-theme icon.
class DesktopIconService {
  DesktopIconService();

  static DesktopIconService instance = DesktopIconService();

  @visibleForTesting
  static set testInstance(DesktopIconService? value) {
    instance = value ?? DesktopIconService();
  }

  static bool? _supportedOverride;

  /// Test hook — when non-null, replaces the platform check.
  @visibleForTesting
  static set supportedOverride(bool? value) => _supportedOverride = value;

  static bool get isSupported {
    if (_supportedOverride != null) return _supportedOverride!;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  static const shortcutFileName = 'S1er.lnk';

  static const _slgpRawPath = 4;
  static const _shcneAssocChanged = 0x08000000;
  static const _shcnfIdList = 0;

  /// Applies [iconId] to the window/taskbar icon and refreshes the managed
  /// shortcut when one exists. Returns false when the platform or an OS call
  /// fails (the caller rolls the setting back).
  Future<bool> apply(String iconId) async {
    if (!isSupported) return false;
    final variant = _variantFor(iconId);
    try {
      final icoPath = await _ensureIco(variant);
      _setWindowIcon(icoPath);
      if (await shortcutStatus() == DesktopShortcutStatus.ours) {
        // Best effort: a stale shortcut icon must not roll back a theme that
        // the window already switched to.
        try {
          _writeShortcut(icoPath);
          _notifyShell();
        } on Object catch (e, st) {
          talker.handle(e, st, 'DesktopIconService shortcut refresh failed');
        }
      }
      return true;
    } on Object catch (e, st) {
      talker.handle(e, st, 'DesktopIconService.apply($iconId) failed');
      return false;
    }
  }

  Future<DesktopShortcutStatus> shortcutStatus() async {
    if (!isSupported) return DesktopShortcutStatus.missing;
    try {
      final lnkPath = _shortcutPath();
      if (!await File(lnkPath).exists()) {
        return DesktopShortcutStatus.missing;
      }
      final target = _readShortcutTarget(lnkPath);
      if (target == null) return DesktopShortcutStatus.foreign;
      return p.equals(target, Platform.resolvedExecutable)
          ? DesktopShortcutStatus.ours
          : DesktopShortcutStatus.foreign;
    } on Object catch (e, st) {
      talker.handle(e, st, 'DesktopIconService.shortcutStatus failed');
      return DesktopShortcutStatus.foreign;
    }
  }

  /// Creates or refreshes the desktop shortcut with [iconId].
  Future<DesktopShortcutResult> createShortcut(String iconId) async {
    if (!isSupported) return DesktopShortcutResult.unsupported;
    try {
      final status = await shortcutStatus();
      if (status == DesktopShortcutStatus.foreign) {
        return DesktopShortcutResult.nameConflict;
      }
      final variant = _variantFor(iconId);
      final icoPath = await _ensureIco(variant);
      _writeShortcut(icoPath);
      _notifyShell();
      return DesktopShortcutResult.created;
    } on Object catch (e, st) {
      talker.handle(e, st, 'DesktopIconService.createShortcut failed');
      return DesktopShortcutResult.failed;
    }
  }

  /// Deletes the shortcut only when it points at this executable.
  Future<DesktopShortcutResult> removeShortcut() async {
    if (!isSupported) return DesktopShortcutResult.unsupported;
    try {
      switch (await shortcutStatus()) {
        case DesktopShortcutStatus.missing:
          return DesktopShortcutResult.notFound;
        case DesktopShortcutStatus.foreign:
          return DesktopShortcutResult.nameConflict;
        case DesktopShortcutStatus.ours:
          break;
      }
      await File(_shortcutPath()).delete();
      _notifyShell();
      return DesktopShortcutResult.removed;
    } on Object catch (e, st) {
      talker.handle(e, st, 'DesktopIconService.removeShortcut failed');
      return DesktopShortcutResult.failed;
    }
  }

  AppIconVariant _variantFor(String iconId) {
    final normalized = AppIconCatalog.normalize(iconId);
    return AppIconCatalog.variants.firstWhere(
      (variant) => variant.id == normalized,
      orElse: () => AppIconCatalog.variants.first,
    );
  }

  /// Writes `<app support>/icons/<theme>.ico` and returns its path.
  Future<String> _ensureIco(AppIconVariant variant) async {
    final data = await rootBundle.load(variant.previewAsset);
    final ico = buildWindowsIco(data.buffer.asUint8List());
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'icons'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${variant.id}.ico'));
    await file.writeAsBytes(ico, flush: true);
    return file.path;
  }

  String _shortcutPath() {
    final buffer = wsalloc(MAX_PATH);
    try {
      SHGetFolderPath(CSIDL_DESKTOPDIRECTORY, null, 0, buffer);
      return p.join(buffer.toDartString(), shortcutFileName);
    } finally {
      free(buffer);
    }
  }

  String? _readShortcutTarget(String lnkPath) {
    _ensureCom();
    return using((arena) {
      final link = arena.com<IShellLink>(_clsidShellLink);
      final persist = IPersistFile.from(link);
      persist.load(arena.pcwstr(lnkPath), STGM_READ);
      final buffer = arena.pwstrBuffer(MAX_PATH);
      link.getPath(buffer, MAX_PATH, nullptr, _slgpRawPath);
      final target = buffer.toDartString();
      return target.isEmpty ? null : target;
    });
  }

  void _writeShortcut(String icoPath) {
    _ensureCom();
    final target = Platform.resolvedExecutable;
    final lnkPath = _shortcutPath();
    using((arena) {
      final link = arena.com<IShellLink>(_clsidShellLink);
      link.setPath(arena.pcwstr(target));
      link.setWorkingDirectory(arena.pcwstr(p.dirname(target)));
      link.setDescription(arena.pcwstr('S1er'));
      link.setIconLocation(arena.pcwstr(icoPath), 0);
      link.setShowCmd(SW_SHOWNORMAL);
      IPersistFile.from(link).save(arena.pcwstr(lnkPath), true);
    });
  }

  void _ensureCom() {
    try {
      CoInitializeEx(COINIT_APARTMENTTHREADED);
    } on Object catch (e, st) {
      talker.handle(e, st, 'DesktopIconService CoInitializeEx failed');
    }
  }

  void _notifyShell() {
    try {
      _shChangeNotify(_shcneAssocChanged, _shcnfIdList, nullptr, nullptr);
    } on Object catch (e, st) {
      talker.handle(e, st, 'DesktopIconService SHChangeNotify failed');
    }
  }
}

final _clsidShellLink = GUID.fromComponents(
  0x00021401,
  0,
  0,
  Uint8List.fromList(const [0xc0, 0, 0, 0, 0, 0, 0, 0x46]),
);

// ── Window icon ─────────────────────────────────────────────────────────────
//
// `window_manager.setIcon` passes the path to `LoadImage`, which rejects PNG
// files, so the generated multi-size `.ico` is applied directly with Win32.

const _wmSetIcon = 0x0080;
const _iconSmall = 0;
const _iconBig = 1;
const _imageIcon = 1;
const _lrLoadFromFile = 0x00000010;

typedef _EnumWindowsNative = Int32 Function(
  Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>,
  IntPtr,
);
typedef _EnumWindowsDart = int Function(
  Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>,
  int,
);

final _user32 = DynamicLibrary.open('user32.dll');

final _enumWindows =
    _user32.lookupFunction<_EnumWindowsNative, _EnumWindowsDart>('EnumWindows');

final _getWindowThreadProcessId = _user32.lookupFunction<
    Uint32 Function(IntPtr, Pointer<Uint32>),
    int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');

final _getWindowTextLength =
    _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
  'GetWindowTextLengthW',
);

final _getWindowText = _user32.lookupFunction<
    Int32 Function(IntPtr, Pointer<Utf16>, Int32),
    int Function(int, Pointer<Utf16>, int)>('GetWindowTextW');

final _loadImage = _user32.lookupFunction<
    IntPtr Function(IntPtr, Pointer<Utf16>, Uint32, Int32, Int32, Uint32),
    int Function(int, Pointer<Utf16>, int, int, int, int)>('LoadImageW');

final _sendMessage = _user32.lookupFunction<
    IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr),
    int Function(int, int, int, int)>('SendMessageW');

int _enumPid = 0;
int _enumHwnd = 0;

/// Replaces the small and large window icons (title bar, taskbar preview).
void _setWindowIcon(String icoPath) {
  final hwnd = _findMainWindow();
  if (hwnd == 0) {
    throw StateError('main window not found');
  }
  using((arena) {
    final small = _loadImage(
      0,
      arena.pcwstr(icoPath),
      _imageIcon,
      16,
      16,
      _lrLoadFromFile,
    );
    final big = _loadImage(
      0,
      arena.pcwstr(icoPath),
      _imageIcon,
      32,
      32,
      _lrLoadFromFile,
    );
    if (small == 0 || big == 0) {
      throw StateError('LoadImage failed for $icoPath');
    }
    _sendMessage(hwnd, _wmSetIcon, _iconSmall, small);
    _sendMessage(hwnd, _wmSetIcon, _iconBig, big);
  });
}

/// Finds the top-level window owned by this process.
int _findMainWindow() {
  _enumPid = GetCurrentProcessId();
  _enumHwnd = 0;
  _enumWindows(_enumWindowsCallback, 0);
  return _enumHwnd;
}

final _enumWindowsCallback =
    Pointer.fromFunction<Int32 Function(IntPtr, IntPtr)>(_enumWindowProc, 0);

int _enumWindowProc(int hwnd, int lParam) {
  final pid = calloc<Uint32>();
  try {
    _getWindowThreadProcessId(hwnd, pid);
    if (pid.value != _enumPid) return 1;
  } finally {
    free(pid);
  }
  // Match the main window by exact title. A same-process GDI+ helper window
  // titled "GDI+ Window (s1er.exe)" also passes a length-only check.
  final length = _getWindowTextLength(hwnd);
  if (length != S1Constants.appName.length) return 1;
  final text = calloc<Uint16>(length + 1);
  try {
    _getWindowText(hwnd, text.cast<Utf16>(), length + 1);
    if (text.cast<Utf16>().toDartString() != S1Constants.appName) return 1;
  } finally {
    free(text);
  }
  _enumHwnd = hwnd;
  return 0;
}

typedef _ShChangeNotifyNative = Void Function(Int32, Uint32, Pointer, Pointer);
typedef _ShChangeNotifyDart = void Function(int, int, Pointer, Pointer);

final _shChangeNotify = DynamicLibrary.open('shell32.dll')
    .lookupFunction<_ShChangeNotifyNative, _ShChangeNotifyDart>(
  'SHChangeNotify',
);
