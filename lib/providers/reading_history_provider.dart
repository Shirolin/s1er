import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_record.dart';
import '../services/reading_history_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

/// 依赖登录态获取当前 uid，实现按用户隔离。
final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  final local = ref.watch(localDataProvider);
  final rawUid = ref.watch(authStateProvider).user?.uid;
  final uid = (rawUid == null || rawUid.isEmpty) ? 'guest' : rawUid;
  return ReadingHistoryService(local, uid);
});

/// 单条帖子的阅读记录（供 ThreadCard / ThreadDetailScreen 使用）。
final readingRecordProvider = Provider.family<ReadingRecord?, String>((ref, tid) {
  return ref.watch(readingHistoryServiceProvider).getRecord(tid);
});

final readingHistoryProvider =
    StateNotifierProvider<ReadingHistoryNotifier, List<ReadingRecord>>((ref) {
  return ReadingHistoryNotifier(ref.watch(readingHistoryServiceProvider));
});

class ReadingHistoryNotifier extends StateNotifier<List<ReadingRecord>> {
  ReadingHistoryNotifier(this._service) : super(_service.getAllRecords());

  final ReadingHistoryService _service;

  void refresh() => state = _service.getAllRecords();

  void delete(String tid) {
    _service.deleteRecord(tid);
    state = _service.getAllRecords();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    state = [];
  }
}
