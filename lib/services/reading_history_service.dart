import '../models/reading_record.dart';
import 'app_local_data.dart';

/// 阅读历史服务层：封装本地 CRUD 与按用户隔离的 LRU 淘汰。
///
/// - 接收已在 `main.dart` 初始化的 [AppLocalData]，不自行 open（遵守架构边界）。
/// - key 格式 `{uid}_{tid}`，实现多账号隔离；uid 为空时调用方应传 `guest`。
class ReadingHistoryService {
  ReadingHistoryService(this._local, this._uid);

  final AppLocalData _local;
  final String _uid;

  static const int maxRecords = 500;

  String _key(String tid) => '${_uid}_$tid';

  bool _belongsToUser(String key) => key.startsWith('${_uid}_');

  void updateProgress({
    required String tid,
    required int page,
    required int floorInPage,
    required String subject,
    required String author,
    required String fid,
    required int totalPages,
    required int totalReplies,
    required int perPage,
    bool isNewVisit = false,
  }) {
    if (tid.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final absoluteFloor = (page - 1) * perPage + floorInPage;
    final key = _key(tid);
    final existing = _local.readingHistory[key];
    final firstReadAt = existing != null
        ? ((existing['firstReadAt'] as num?)?.toInt() ?? now)
        : now;
    final prevCount =
        existing != null ? ((existing['readCount'] as num?)?.toInt() ?? 0) : 0;

    final record = ReadingRecord(
      tid: tid,
      subject: subject,
      author: author,
      fid: fid,
      lastReadPage: page,
      lastReadFloor: absoluteFloor,
      totalPages: totalPages,
      totalReplies: totalReplies,
      perPage: perPage,
      lastReadAt: now,
      firstReadAt: firstReadAt,
      readCount: isNewVisit ? prevCount + 1 : (prevCount == 0 ? 1 : prevCount),
    );
    _local.putReadingRecord(_uid, record);
    _evictIfNeeded();
  }

  ReadingRecord? getRecord(String tid) {
    final data = _local.readingHistory[_key(tid)];
    if (data == null) return null;
    return ReadingRecord.fromJson(Map<String, dynamic>.from(data));
  }

  List<ReadingRecord> getAllRecords() {
    final records = <ReadingRecord>[];
    for (final entry in _local.readingHistory.entries) {
      if (!_belongsToUser(entry.key)) continue;
      records.add(ReadingRecord.fromJson(Map<String, dynamic>.from(entry.value)));
    }
    records.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return records;
  }

  int get count =>
      _local.readingHistory.keys.where(_belongsToUser).length;

  void deleteRecord(String tid) {
    _local.deleteReadingRecord(_uid, tid);
  }

  Future<void> clearAll() => _local.clearReadingRecords(_uid);

  void migrateGuestRecords(String uid) {
    if (uid.isEmpty) return;
    const guestPrefix = 'guest_';
    final toMigrate = <String, Map<String, dynamic>>{};
    for (final entry in _local.readingHistory.entries) {
      if (!entry.key.startsWith(guestPrefix)) continue;
      final tid = entry.key.substring(guestPrefix.length);
      toMigrate[tid] = Map<String, dynamic>.from(entry.value);
    }
    for (final entry in toMigrate.entries) {
      final record = ReadingRecord.fromJson(entry.value);
      _local.putReadingRecord(
        uid,
        ReadingRecord(
          tid: entry.key,
          subject: record.subject,
          author: record.author,
          fid: record.fid,
          lastReadPage: record.lastReadPage,
          lastReadFloor: record.lastReadFloor,
          totalPages: record.totalPages,
          totalReplies: record.totalReplies,
          perPage: record.perPage,
          lastReadAt: record.lastReadAt,
          firstReadAt: record.firstReadAt,
          readCount: record.readCount,
        ),
      );
      _local.deleteReadingRecord('guest', entry.key);
    }
  }

  void _evictIfNeeded() {
    final keys =
        _local.readingHistory.keys.where(_belongsToUser).toList();
    if (keys.length <= maxRecords) return;
    keys.sort((a, b) {
      final at =
          (_local.readingHistory[a]?['lastReadAt'] as num?)?.toInt() ?? 0;
      final bt =
          (_local.readingHistory[b]?['lastReadAt'] as num?)?.toInt() ?? 0;
      return at.compareTo(bt);
    });
    final removeCount = keys.length - maxRecords;
    for (final key in keys.take(removeCount)) {
      final tid = key.substring('${_uid}_'.length);
      _local.deleteReadingRecord(_uid, tid);
    }
  }
}
