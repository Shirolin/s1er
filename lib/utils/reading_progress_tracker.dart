import '../config/constants.dart';
import '../models/reading_record.dart';

/// 阅读进度写回用的页内楼层（1-based）。
///
/// 平常取视口锚线上方最后一楼；已滚到页底时取本页末楼，避免短帖读完后仍停在较早楼层。
/// [minFloorInPage] 用于同页内单调递增，防止从页底回滑时进度回退。
int resolveFloorInPageForProgress({
  required int leadingIndex,
  required int postCount,
  required bool atPageBottom,
  int minFloorInPage = 1,
}) {
  if (postCount <= 0) return 1;
  final raw =
      atPageBottom ? postCount : leadingIndex.clamp(0, postCount - 1) + 1;
  return raw < minFloorInPage ? minFloorInPage : raw;
}

/// 本屏会话内的阅读进度状态与写回策略。
///
/// 持有「是否已首写 / 上次写回的页与页内楼 / 各页记忆位」，并给出：
/// - [shouldWrite]：本次是否该写库（去重）；
/// - [minProgressFloorInPage]：同页高水位下界（防回退）；
/// - [markRecorded] / [pageFloorMemory]：写回后与翻页记忆的维护。
///
/// 只做状态与策略，不触碰渲染树 / provider；由屏幕在适当的 render 时机调用。
class ReadingProgressTracker {
  bool hasRecordedInitialVisit = false;
  int? lastRecordedPage;
  int? lastRecordedFloorInPage;

  /// 本次进入详情后的页内阅读位（页码 → 页内 1-based 楼层），翻回该页时恢复。
  final Map<int, int> pageFloorMemory = {};

  /// 本次是否该写库（首访必写；其后仅页 / 页内楼变化才写）。
  bool shouldWrite({
    required int currentPage,
    required int currentFloorInPage,
  }) {
    if (!hasRecordedInitialVisit) return true;
    if (lastRecordedPage != currentPage) return true;
    return lastRecordedFloorInPage != currentFloorInPage;
  }

  /// 同页写回的下界：不低于本会话已写回的页内楼，也不低于服务器已持久化的
  /// 页内楼，防止回滑把进度写低。
  int minProgressFloorInPage({
    required int currentPage,
    required int perPage,
    int? persistedLastReadFloor,
  }) {
    var minFloor = 1;
    if (lastRecordedPage == currentPage && lastRecordedFloorInPage != null) {
      minFloor = lastRecordedFloorInPage!;
    }
    if (persistedLastReadFloor != null) {
      final ppp = perPage > 0 ? perPage : S1Constants.postsPerPageFallback;
      if (pageForFloor(persistedLastReadFloor, perPage: ppp) == currentPage) {
        final persistedInPage =
            persistedLastReadFloor - (currentPage - 1) * ppp;
        if (persistedInPage > minFloor) minFloor = persistedInPage;
      }
    }
    return minFloor;
  }

  /// 记录一次已写回的进度。
  void markRecorded({required int page, required int floorInPage}) {
    hasRecordedInitialVisit = true;
    lastRecordedPage = page;
    lastRecordedFloorInPage = floorInPage;
  }

  /// 记录本页的页内阅读位（翻回该页时恢复）。
  void rememberFloor({required int page, required int floorInPage}) =>
      pageFloorMemory[page] = floorInPage;

  /// 清空翻页记忆（过滤作者等改变楼层布局时调用）。
  void clearPageFloorMemory() => pageFloorMemory.clear();
}
