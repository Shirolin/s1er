/// Desktop tray façade.
///
/// `tray_manager` reaches `dart:io` through `nativeapi_flutter`, so the Web
/// build must not import it; it gets a no-op stub instead.
library;

export 'desktop_tray_io.dart'
    if (dart.library.js_interop) 'desktop_tray_web.dart';
