import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pinned_thread.dart';
import '../providers/api_service_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/talker_provider.dart';

const int kMaxPinnedThreadsCount = 10;

/// 单帖两次 viewthread 拉取回复数的最小间隔。
const int kPinnedReplyFetchCooldownSeconds = 30 * 60;

/// 进 app 后延迟启动置顶回复数同步。
const Duration kPinnedReplySyncStartupDelay = Duration(seconds: 5);

/// 后台逐钉拉取之间的间隔。
const Duration kPinnedReplySyncInterval = Duration(seconds: 3);

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
      lastFetchedAt: replies != null ? now : null,
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

  /// 规则 3：更新 live；lastSeen 为空时一并 seed（首次同步，角标为 0）。
  void applyLiveReplies(
    String tid,
    int replies, {
    int? lastFetchedAt,
  }) {
    if (tid.isEmpty || replies < 0) return;
    final index = state.indexWhere((t) => t.tid == tid);
    if (index < 0) return;

    final updated = _applyLiveRepliesToThread(
      state[index],
      replies,
      lastFetchedAt: lastFetchedAt,
    );
    if (updated == null) return;

    final next = [...state];
    next[index] = updated;
    _persist(next);
  }

  /// 版块列表顺带回填 live 回复数（零额外请求）；不改 lastSeen。
  void mergeReplyCounts(Map<String, int> tidToReplies) {
    if (tidToReplies.isEmpty || state.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var changed = false;
    final next = <PinnedThread>[];

    for (final thread in state) {
      final live = tidToReplies[thread.tid];
      if (live == null) {
        next.add(thread);
        continue;
      }
      final updated = _applyLiveRepliesToThread(
        thread,
        live,
        lastFetchedAt: now,
      );
      if (updated != null) {
        changed = true;
        next.add(updated);
      } else {
        next.add(thread);
      }
    }

    if (changed) _persist(next);
  }

  /// 打开置顶帖：live 与 lastSeen 对齐，角标清零；并 stamp 拉取时间（详情已含 fresh replies）。
  void markOpened(String tid, int replies) {
    if (tid.isEmpty || replies < 0) return;
    final index = state.indexWhere((t) => t.tid == tid);
    if (index < 0) return;
    final current = state[index];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (current.lastKnownReplies == replies &&
        current.lastSeenReplies == replies &&
        _isWithinFetchCooldown(current, now)) {
      return;
    }
    final next = [...state];
    next[index] = current.copyWith(
      lastKnownReplies: replies,
      lastSeenReplies: replies,
      lastFetchedAt: now,
    );
    _persist(next);
  }

  /// 进 app 后按 displayOrder 慢速拉取过期钉的回复数。
  Future<void> syncAllStaleReplyCounts({
    Duration startupDelay = kPinnedReplySyncStartupDelay,
    Duration interval = kPinnedReplySyncInterval,
  }) async {
    await Future<void>.delayed(startupDelay);
    if (!ref.mounted || state.isEmpty) return;

    final api = ref.read(apiServiceProvider);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (final thread in state) {
      if (!ref.mounted) return;
      if (_isWithinFetchCooldown(thread, now)) continue;

      try {
        final replies = await api.fetchThreadReplies(thread.tid);
        if (!ref.mounted) return;
        if (replies == null) {
          _stampLastFetchedAt(thread.tid, now);
        } else {
          applyLiveReplies(thread.tid, replies, lastFetchedAt: now);
        }
      } catch (e, st) {
        ref.read(talkerProvider).handle(
              e,
              st,
              'pinned reply sync failed tid=${thread.tid}',
            );
        if (ref.mounted) {
          _stampLastFetchedAt(thread.tid, now);
        }
      }

      await Future<void>.delayed(interval);
    }
  }

  /// 规则 3 纯内存变换；无变更时返回 null。
  PinnedThread? _applyLiveRepliesToThread(
    PinnedThread current,
    int replies, {
    int? lastFetchedAt,
  }) {
    if (replies < 0) return null;

    final seedSeen = current.lastSeenReplies == null;
    if (!seedSeen && current.lastKnownReplies == replies) {
      if (lastFetchedAt == null || lastFetchedAt == current.lastFetchedAt) {
        return null;
      }
    }

    return current.copyWith(
      lastKnownReplies: replies,
      lastSeenReplies: seedSeen ? replies : current.lastSeenReplies,
      lastFetchedAt: lastFetchedAt ?? current.lastFetchedAt,
    );
  }

  void _stampLastFetchedAt(String tid, int lastFetchedAt) {
    if (tid.isEmpty) return;
    final index = state.indexWhere((t) => t.tid == tid);
    if (index < 0) return;

    final current = state[index];
    if (current.lastFetchedAt == lastFetchedAt) return;

    final next = [...state];
    next[index] = current.copyWith(lastFetchedAt: lastFetchedAt);
    _persist(next);
  }

  bool _isWithinFetchCooldown(PinnedThread thread, int nowSeconds) {
    final fetchedAt = thread.lastFetchedAt;
    if (fetchedAt == null) return false;
    return nowSeconds - fetchedAt < kPinnedReplyFetchCooldownSeconds;
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
