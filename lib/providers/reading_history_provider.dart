import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_record.dart';
import '../services/reading_history_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  final local = ref.watch(localDataProvider);
  final rawUid = ref.watch(authStateProvider).user?.uid;
  final uid = (rawUid == null || rawUid.isEmpty) ? 'guest' : rawUid;
  return ReadingHistoryService(local, uid);
});

final readingRecordProvider =
    Provider.family<ReadingRecord?, String>((ref, tid) {
  return ref.watch(readingHistoryServiceProvider).getRecord(tid);
});

class ReadingHistoryNotifier extends Notifier<List<ReadingRecord>> {
  @override
  List<ReadingRecord> build() {
    return ref.watch(readingHistoryServiceProvider).getAllRecords();
  }

  void refresh() =>
      state = ref.read(readingHistoryServiceProvider).getAllRecords();

  void delete(String tid) {
    ref.read(readingHistoryServiceProvider).deleteRecord(tid);
    state = ref.read(readingHistoryServiceProvider).getAllRecords();
  }

  Future<void> clearAll() async {
    await ref.read(readingHistoryServiceProvider).clearAll();
    state = [];
  }
}

final readingHistoryProvider =
    NotifierProvider<ReadingHistoryNotifier, List<ReadingRecord>>(
  ReadingHistoryNotifier.new,
);
