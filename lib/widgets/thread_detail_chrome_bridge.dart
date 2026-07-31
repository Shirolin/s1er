import 'package:flutter/foundation.dart';

import '../models/list_density.dart';

/// Snapshot of thread-detail toolbar state/actions for a parent breadcrumb AppBar.
class ThreadDetailChromeSnapshot {
  const ThreadDetailChromeSnapshot({
    this.pageSearchOpen = false,
    this.shareSelectMode = false,
    this.isPinned = false,
    this.browserUrl,
    this.postListDensity,
    this.onRefresh,
    this.onTogglePageSearch,
    this.onGoToLatest,
    this.onTogglePin,
    this.onPostListDensityChanged,
    this.onPrevPage,
    this.onNextPage,
    this.canPrevPage = false,
    this.canNextPage = false,
  });

  final bool pageSearchOpen;
  final bool shareSelectMode;
  final bool isPinned;
  final String? browserUrl;
  final ListDensity? postListDensity;
  final VoidCallback? onRefresh;
  final VoidCallback? onTogglePageSearch;
  final VoidCallback? onGoToLatest;
  final VoidCallback? onTogglePin;
  final ValueChanged<ListDensity>? onPostListDensityChanged;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final bool canPrevPage;
  final bool canNextPage;
}

/// Bridges thread-detail toolbar actions to [ForumListScreen]'s split AppBar.
class ThreadDetailChromeBridge extends ChangeNotifier {
  ThreadDetailChromeSnapshot? _snapshot;

  ThreadDetailChromeSnapshot? get snapshot => _snapshot;

  void publish(ThreadDetailChromeSnapshot snapshot) {
    final prev = _snapshot;
    if (prev != null &&
        prev.pageSearchOpen == snapshot.pageSearchOpen &&
        prev.shareSelectMode == snapshot.shareSelectMode &&
        prev.isPinned == snapshot.isPinned &&
        prev.browserUrl == snapshot.browserUrl &&
        prev.postListDensity == snapshot.postListDensity &&
        prev.canPrevPage == snapshot.canPrevPage &&
        prev.canNextPage == snapshot.canNextPage) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  void clear() {
    if (_snapshot == null) return;
    _snapshot = null;
    notifyListeners();
  }
}
