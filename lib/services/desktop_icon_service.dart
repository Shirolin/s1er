/// Desktop icon façade.
///
/// The Windows implementation reaches `dart:ffi` and Win32 COM; the Web build
/// gets a no-op stub.
library;

export 'desktop_icon_service_io.dart'
    if (dart.library.js_interop) 'desktop_icon_service_web.dart';
