import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_local_data.dart';
import '../services/reading_history_service.dart';
import 'reading_history_provider.dart';
import 'settings_provider.dart';

bool _hasGuestKeys(AppLocalData local) {
  return local.readingHistory.keys.any((key) => key.startsWith('guest_'));
}

/// 协调阅读历史在 uid 切换时的副作用：guest→登录合并、service 重建、列表刷新。
///
/// 在应用根 [ref.watch] 以保持 listener 始终活跃。
final readingHistoryCoordinatorProvider = Provider<void>((ref) {
  Future<void> applyUidChange(String? previous, String next) async {
    if (previous == next) return;
    if (previous == null && next == 'guest') return;
    if (!ref.mounted) return;

    await ref.read(localDataProvider).ensureReadingHistoryLoaded();
    if (!ref.mounted) return;

    final local = ref.read(localDataProvider);
    final shouldMigrate = next != 'guest' &&
        (previous == 'guest' || previous == null) &&
        _hasGuestKeys(local);
    if (shouldMigrate) {
      ReadingHistoryService(local, next).migrateGuestRecords(next);
    }

    ref.invalidate(readingHistoryServiceProvider);
  }

  ref.listen(currentReadingUidProvider, (previous, next) {
    scheduleMicrotask(() => applyUidChange(previous, next));
  });

  // 冷启动已登录且仍有 guest_* 残留时幂等合并。
  scheduleMicrotask(() async {
    if (!ref.mounted) return;
    final uid = ref.read(currentReadingUidProvider);
    if (uid == 'guest') return;
    await ref.read(localDataProvider).ensureReadingHistoryLoaded();
    if (!ref.mounted) return;
    if (_hasGuestKeys(ref.read(localDataProvider))) {
      await applyUidChange('guest', uid);
    }
  });
});
