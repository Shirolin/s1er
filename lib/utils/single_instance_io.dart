import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../services/talker.dart';

/// Named mutex that marks "the app is already running" for the current user.
const _mutexName = 'Local\\S1er.SingleInstance';

/// Fixed window title of the main window (set by the Windows runner).
const _windowTitle = 'S1er';

const _synchronize = 0x00100000;
const _waitObject0 = 0x0;
const _waitAbandoned = 0x80;
const _swRestore = 9;
const _swShow = 5;

/// Win32 entry points, resolved lazily so non-Windows `dart:io` platforms
/// never try to load kernel32/user32.
abstract final class _Win32 {
  static final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

  static final createMutex = _kernel32.lookupFunction<
      IntPtr Function(Pointer<Void>, Int32, Pointer<Utf16>),
      int Function(Pointer<Void>, int, Pointer<Utf16>)>('CreateMutexW');
  static final openMutex = _kernel32.lookupFunction<
      IntPtr Function(Uint32, Int32, Pointer<Utf16>),
      int Function(int, int, Pointer<Utf16>)>('OpenMutexW');
  static final closeHandle =
      _kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
    'CloseHandle',
  );
  static final waitForSingleObject = _kernel32.lookupFunction<
      Uint32 Function(IntPtr, Uint32),
      int Function(int, int)>('WaitForSingleObject');
  static final findWindow = _user32.lookupFunction<
      IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
      int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');
  static final showWindow = _user32
      .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
    'ShowWindow',
  );
  static final isIconic =
      _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
    'IsIconic',
  );
  static final setForegroundWindow =
      _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
    'SetForegroundWindow',
  );
}

/// Returns true when this process may continue; otherwise brings the existing
/// instance forward and exits.
///
/// [updateHandoff] marks a process started by the overlay updater: the copy it
/// replaces is still alive, so the duplicate check must not reject it. It still
/// takes a handle on the mutex, so the app stays single-instance once the old
/// process exits.
bool ensurePrimary({bool updateHandoff = false}) {
  if (!Platform.isWindows) return true;
  try {
    if (updateHandoff) {
      // Just hold the mutex; the handle is released by the OS at exit.
      _createMutex();
      return true;
    }
    if (_acquire()) return true;
    _activateExisting();
    exit(0);
  } on Object catch (e, st) {
    // Never block startup on a failed check.
    talker.handle(e, st, 'Single-instance check failed');
  }
  return true;
}

int _createMutex() => using(
      (arena) => _Win32.createMutex(
        nullptr,
        // Own the mutex so a racing copy can tell it is not the first one.
        1,
        _mutexName.toNativeUtf16(allocator: arena),
      ),
    );

/// Checks whether [handle] owns the mutex right now.
///
/// `CreateMutexW` reports "already exists" through `GetLastError`, which Dart
/// on Flutter reports as 0 even when the mutex is pre-existing, so ownership is
/// the only reliable signal: a freshly created mutex is owned by its creator,
/// one another copy owns stays unowned for us.
bool _owns(int handle) {
  final result = _Win32.waitForSingleObject(handle, 0);
  return result == _waitObject0 || result == _waitAbandoned;
}

/// False means another copy created the mutex first.
bool _acquire() {
  final existing = using(
    (arena) => _Win32.openMutex(
      _synchronize,
      0,
      _mutexName.toNativeUtf16(allocator: arena),
    ),
  );
  if (existing != 0) {
    // Existence alone is enough: older builds create the mutex without owning
    // it, and those instances must also count as "already running".
    _Win32.closeHandle(existing);
    return false;
  }

  final handle = _createMutex();
  if (handle == 0) return true;
  // Keep the handle open for the process lifetime; never close it here.
  if (_owns(handle)) return true;
  // Lost the race between the existence check and the create.
  _Win32.closeHandle(handle);
  return false;
}

/// Shows the first instance's window (restoring it when minimized).
void _activateExisting() {
  final hwnd = using(
    (arena) => _Win32.findWindow(
      nullptr,
      _windowTitle.toNativeUtf16(allocator: arena),
    ),
  );
  if (hwnd == 0) return;
  final show = _Win32.isIconic(hwnd) != 0 ? _swRestore : _swShow;
  _Win32.showWindow(hwnd, show);
  _Win32.setForegroundWindow(hwnd);
}
