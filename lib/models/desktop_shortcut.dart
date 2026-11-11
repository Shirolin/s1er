/// Ownership of the desktop `S1er.lnk` shortcut.
///
/// [missing] — no shortcut; [ours] — points at this executable and may be
/// updated or deleted; [foreign] — same name but another target, never touched.
enum DesktopShortcutStatus { missing, ours, foreign }

/// Outcome of creating or deleting the desktop shortcut.
enum DesktopShortcutResult {
  created,
  removed,
  notFound,
  nameConflict,
  unsupported,
  failed
}
