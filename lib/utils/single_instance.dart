import 'single_instance_stub.dart'
    if (dart.library.io) 'single_instance_io.dart' as impl;

/// Keeps a second copy of the app from running alongside the first.
///
/// Two instances would show two tray icons, open the same database twice, and
/// make the Windows overlay update more likely to hit files the other copy is
/// holding. Only the first instance keeps running; later launches bring the
/// existing window forward and quit.
///
/// Processes started by the overlay updater are exempt (see `main`): the copy
/// they replace is still alive until it sees the start marker.
abstract final class S1SingleInstance {
  /// Returns normally when this process should continue; otherwise activates
  /// the existing instance and exits.
  ///
  /// Pass [updateHandoff] for a process started by the overlay updater: the
  /// copy it replaces is still alive, so it must not be rejected as a duplicate
  /// (but it still holds the mutex for the rest of its life).
  static void ensurePrimary({bool updateHandoff = false}) =>
      impl.ensurePrimary(updateHandoff: updateHandoff);
}
