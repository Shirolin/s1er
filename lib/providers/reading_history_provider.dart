import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading_history_state.dart';

import '../models/reading_record.dart';

import '../services/reading_history_service.dart';

import 'auth_provider.dart';

import 'settings_provider.dart';

/// Ensures reading history table is loaded before service access.
final readingHistoryBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(localDataProvider).ensureReadingHistoryLoaded();
});

/// Ensures poll vote table is loaded before cache access.
final pollVotesBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(localDataProvider).ensurePollVotesLoaded();
});

/// 阅读历史命名空间：未登录为 guest，已登录为真实 uid。

final currentReadingUidProvider = Provider<String>((ref) {
  final raw = ref.watch(authStateProvider.select((a) => a.user?.uid ?? ''));

  return raw.isEmpty ? 'guest' : raw;
});

final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  ref.watch(readingHistoryBootstrapProvider);
  final local = ref.watch(localDataProvider);
  final uid = ref.watch(currentReadingUidProvider);
  return ReadingHistoryService(local, uid);
});

/// 按 tid 订阅阅读历史列表中的单条记录（随 [upsert] 增量更新）。

final readingRecordProvider =
    Provider.family<ReadingRecord?, String>((ref, tid) {
  return ref.watch(readingHistoryProvider.select((s) => s.byTid[tid]));
});

class ReadingHistoryNotifier extends Notifier<ReadingHistoryState> {
  @override
  ReadingHistoryState build() {
    final records = ref.watch(readingHistoryServiceProvider).getAllRecords();

    return ReadingHistoryState.fromRecords(records);
  }

  void refresh() {
    final records = ref.read(readingHistoryServiceProvider).getAllRecords();

    state = ReadingHistoryState.fromRecords(records);
  }

  /// 增量更新单条记录（按 lastReadAt 排序，上限 [ReadingHistoryService.maxRecords]）。

  void upsert(ReadingRecord record) {
    final updated = [...state.records];

    final idx = updated.indexWhere((r) => r.tid == record.tid);

    if (idx >= 0) {
      updated[idx] = record;
    } else {
      updated.add(record);
    }

    updated.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));

    final trimmed = updated.length > ReadingHistoryService.maxRecords
        ? updated.take(ReadingHistoryService.maxRecords).toList()
        : updated;

    state = ReadingHistoryState.fromRecords(trimmed);
  }

  void delete(String tid) {
    ref.read(readingHistoryServiceProvider).deleteRecord(tid);

    final records = state.records.where((r) => r.tid != tid).toList();

    state = ReadingHistoryState.fromRecords(records);
  }

  Future<void> clearAll() async {
    await ref.read(readingHistoryServiceProvider).clearAll();

    state = ReadingHistoryState.empty;
  }
}

final readingHistoryProvider =
    NotifierProvider<ReadingHistoryNotifier, ReadingHistoryState>(
  ReadingHistoryNotifier.new,
);
