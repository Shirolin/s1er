import '../models/post.dart';
import '../models/share_floor_data.dart';
import 'share_capture_policy.dart';

/// Immutable helpers for multi-floor share selection (pid-deduped snapshots).
class ShareFloorSelection {
  ShareFloorSelection._();

  /// Toggle [post] in [current]. Returns updated list, or `null` when add is
  /// blocked by the soft cap (caller should show a snackbar).
  static List<ShareFloorData>? toggle({
    required List<ShareFloorData> current,
    required Post post,
    required int displayFloor,
  }) {
    final index = current.indexWhere((e) => e.post.pid == post.pid);
    if (index >= 0) {
      return [...current]..removeAt(index);
    }
    if (!canAddShareFloor(currentCount: current.length)) {
      return null;
    }
    return [
      ...current,
      ShareFloorData(post: post, displayFloor: displayFloor),
    ];
  }

  /// Sort by [ShareFloorData.displayFloor] ascending for export order.
  static List<ShareFloorData> sortedForExport(List<ShareFloorData> floors) {
    final copy = [...floors];
    copy.sort((a, b) => a.displayFloor.compareTo(b.displayFloor));
    return copy;
  }

  static bool containsPid(List<ShareFloorData> floors, String pid) {
    return floors.any((e) => e.post.pid == pid);
  }
}
