import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pinned_thread.dart';
import '../providers/settings_provider.dart';
import '../providers/talker_provider.dart';

const int kMaxPinnedThreadsCount = 10;

class PinnedThreadsNotifier extends Notifier<List<PinnedThread>> {
  @override
  List<PinnedThread> build() {
    try {
      final localData = ref.watch(localDataProvider);
      final list = localData.pinnedThreads
          .map((e) => PinnedThread.fromJson(e))
          .where((t) => t.tid.isNotEmpty)
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      if (list.length > kMaxPinnedThreadsCount) {
        return list.take(kMaxPinnedThreadsCount).toList();
      }
      return list;
    } catch (e, st) {
      ref.read(talkerProvider).handle(e, st, 'pinnedThreads build failed');
      return const [];
    }
  }

  /// Pin a thread. Returns `false` if limit (10) reached.
  ///
  /// [replies] 已知时双侧种子（live = lastSeen），刚钉上角标为 0。
  bool pin({required String tid, required String title, int? replies}) {
    if (tid.isEmpty) return false;
    if (state.any((t) => t.tid == tid)) return true;
    if (state.length >= kMaxPinnedThreadsCount) return false;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newEntry = PinnedThread(
      tid: tid,
      title: title,
      pinnedAt: now,
      displayOrder: state.length,
      lastKnownReplies: replies,
      lastSeenReplies: replies,
    );

    final next = [...state, newEntry];
    _persist(next);
    return true;
  }

  /// Unpin a thread by tid.
  void unpin(String tid) {
    if (tid.isEmpty) return;
    final next = state.where((t) => t.tid != tid).toList();
    _reindexAndSave(next);
  }

  /// Reorder the list after drag & drop.
  void reorder(List<PinnedThread> newList) {
    _reindexAndSave(newList);
  }

  bool isPinned(String tid) {
    return state.any((t) => t.tid == tid);
  }

  /// 版块列表顺带回填 live 回复数（零额外请求）；不改 lastSeen。
  void mergeReplyCounts(Map<String, int> tidToReplies) {
    if (tidToReplies.isEmpty || state.isEmpty) return;
    var changed = false;
    final next = <PinnedThread>[];
    for (final thread in state) {
      final live = tidToReplies[thread.tid];
      if (live == null || live == thread.lastKnownReplies) {
        next.add(thread);
        continue;
      }
      changed = true;
      next.add(thread.copyWith(lastKnownReplies: live));
    }
    if (changed) _persist(next);
  }

  /// 打开置顶帖：live 与 lastSeen 对齐，角标清零。
  void markOpened(String tid, int replies) {
    if (tid.isEmpty || replies < 0) return;
    final index = state.indexWhere((t) => t.tid == tid);
    if (index < 0) return;
    final current = state[index];
    if (current.lastKnownReplies == replies &&
        current.lastSeenReplies == replies) {
      return;
    }
    final next = [...state];
    next[index] = current.copyWith(
      lastKnownReplies: replies,
      lastSeenReplies: replies,
    );
    _persist(next);
  }

  void _reindexAndSave(List<PinnedThread> list) {
    final reindexed = <PinnedThread>[];
    for (var i = 0; i < list.length; i++) {
      reindexed.add(list[i].copyWith(displayOrder: i));
    }
    _persist(reindexed);
  }

  void _persist(List<PinnedThread> list) {
    state = list;
    final localData = ref.read(localDataProvider);
    localData.savePinnedThreads(list.map((t) => t.toJson()).toList());
  }
}

final pinnedThreadsProvider =
    NotifierProvider<PinnedThreadsNotifier, List<PinnedThread>>(
  PinnedThreadsNotifier.new,
);
