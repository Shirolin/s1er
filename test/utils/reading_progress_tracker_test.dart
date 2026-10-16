import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/reading_progress_tracker.dart';

/// 覆盖抽出的 [ReadingProgressTracker]：去重决策、高水位下界、页内记忆。
void main() {
  test('first write happens; unchanged page+floor is skipped', () {
    final tracker = ReadingProgressTracker();
    expect(tracker.shouldWrite(currentPage: 1, currentFloorInPage: 1), isTrue);

    tracker.markRecorded(page: 1, floorInPage: 3);
    expect(tracker.shouldWrite(currentPage: 1, currentFloorInPage: 3), isFalse);
    expect(tracker.shouldWrite(currentPage: 1, currentFloorInPage: 4), isTrue);
    expect(tracker.shouldWrite(currentPage: 2, currentFloorInPage: 3), isTrue);
  });

  test('markRecorded records the first visit and last position', () {
    final tracker = ReadingProgressTracker();
    expect(tracker.hasRecordedInitialVisit, isFalse);
    tracker.markRecorded(page: 4, floorInPage: 7);
    expect(tracker.hasRecordedInitialVisit, isTrue);
    expect(tracker.lastRecordedPage, 4);
    expect(tracker.lastRecordedFloorInPage, 7);
  });

  test('minProgressFloorInPage defaults to 1 without history', () {
    final tracker = ReadingProgressTracker();
    expect(
      tracker.minProgressFloorInPage(currentPage: 2, perPage: 20),
      1,
    );
  });

  test('minProgressFloorInPage never regresses below the last recorded floor',
      () {
    final tracker = ReadingProgressTracker()
      ..markRecorded(page: 2, floorInPage: 12);
    expect(
      tracker.minProgressFloorInPage(currentPage: 2, perPage: 20),
      12,
    );
    // 换页后不再抬高下界。
    expect(
      tracker.minProgressFloorInPage(currentPage: 3, perPage: 20),
      1,
    );
  });

  test('minProgressFloorInPage honors the persisted floor on the same page',
      () {
    final tracker = ReadingProgressTracker();
    // 35 楼在每页 20 的布局下属于第 2 页，页内为 15。
    expect(
      tracker.minProgressFloorInPage(
        currentPage: 2,
        perPage: 20,
        persistedLastReadFloor: 35,
      ),
      15,
    );
    // 45 楼属第 3 页，与当前页不符，不抬高。
    expect(
      tracker.minProgressFloorInPage(
        currentPage: 2,
        perPage: 20,
        persistedLastReadFloor: 45,
      ),
      1,
    );
  });

  test('persisted floor is ignored when perPage falls back', () {
    final tracker = ReadingProgressTracker();
    // perPage 为 0 时用 postsPerPageFallback；仅验证不抛错且给出下界。
    final v = tracker.minProgressFloorInPage(
      currentPage: 1,
      perPage: 0,
      persistedLastReadFloor: 5,
    );
    expect(v, greaterThanOrEqualTo(1));
  });

  test('clearPageFloorMemory drops the per-page memory', () {
    final tracker = ReadingProgressTracker()..pageFloorMemory[2] = 5;
    tracker.clearPageFloorMemory();
    expect(tracker.pageFloorMemory, isEmpty);
  });
}
