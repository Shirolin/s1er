import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/reading_record.dart';
import '../services/reading_history_service.dart';
import 'auth_provider.dart';

/// 已打开的 Hive Box（在 `main.dart` 中 openBox）。
final readingBoxProvider = Provider<Box<Map>>((ref) {
  return Hive.box<Map>('reading_history');
});

/// 依赖登录态获取当前 uid，实现按用户隔离。
final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  final box = ref.watch(readingBoxProvider);
  // User.uid 缺省为空串 ''（非 null），Web 端登录后会短暂为空，必须把空串
  // 也归到 guest，否则 key 前缀会变成 "_{tid}" 污染数据。
  final rawUid = ref.watch(authStateProvider).user?.uid;
  final uid = (rawUid == null || rawUid.isEmpty) ? 'guest' : rawUid;
  return ReadingHistoryService(box, uid);
});

/// 单条帖子的阅读记录（供 ThreadCard / ThreadDetailScreen 使用）。
/// 写入进度后需 `ref.invalidate(readingRecordProvider(tid))` 才会刷新。
final readingRecordProvider = Provider.family<ReadingRecord?, String>((ref, tid) {
  return ref.watch(readingHistoryServiceProvider).getRecord(tid);
});

/// 阅读历史列表（供历史页面使用）。
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
