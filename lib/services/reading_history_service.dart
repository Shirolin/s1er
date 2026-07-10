import 'package:hive/hive.dart';
import '../models/reading_record.dart';

/// 阅读历史服务层：封装 Hive CRUD 与按用户隔离的 LRU 淘汰。
///
/// - 接收已在 `main.dart` 打开的 `Box<Map>`，不自行 openBox（遵守架构边界）。
/// - key 格式 `{uid}_{tid}`，实现多账号隔离；uid 为空时调用方应传 `guest`。
class ReadingHistoryService {
  ReadingHistoryService(this._box, this._uid);

  final Box<Map> _box;
  final String _uid;

  static const int maxRecords = 500;

  String _key(String tid) => '${_uid}_$tid';

  bool _belongsToUser(dynamic key) =>
      key is String && key.startsWith('${_uid}_');

  /// 更新（或创建）阅读进度。
  ///
  /// [isNewVisit] 为本次进入详情页的首帧标记：为 true 时 `readCount + 1`，
  /// 翻页 / 刷新时应传 false，避免重复计数。
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
    final existing = _box.get(key);
    final firstReadAt =
        existing != null ? ((existing['firstReadAt'] as num?)?.toInt() ?? now) : now;
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
    _box.put(key, record.toJson());
    _evictIfNeeded();
  }

  ReadingRecord? getRecord(String tid) {
    final data = _box.get(_key(tid));
    if (data == null) return null;
    return ReadingRecord.fromJson(Map<String, dynamic>.from(data));
  }

  /// 当前用户的全部记录，按 `lastReadAt` 倒序。
  List<ReadingRecord> getAllRecords() {
    final records = <ReadingRecord>[];
    for (final key in _box.keys) {
      if (!_belongsToUser(key)) continue;
      final value = _box.get(key);
      if (value == null) continue;
      records.add(ReadingRecord.fromJson(Map<String, dynamic>.from(value)));
    }
    records.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return records;
  }

  int get count => _box.keys.where(_belongsToUser).length;

  void deleteRecord(String tid) {
    _box.delete(_key(tid));
  }

  /// 仅清空当前用户的记录。
  Future<void> clearAll() async {
    final keys = _box.keys.where(_belongsToUser).toList();
    await _box.deleteAll(keys);
  }

  /// 将 guest_* 记录迁移到真实 uid 前缀（登录后调用一次）
  void migrateGuestRecords(String uid) {
    if (uid.isEmpty) return;
    const guestPrefix = 'guest_';
    final targetPrefix = '${uid}_';
    final toMigrate = <String, Map<dynamic, dynamic>>{};
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(guestPrefix)) continue;
      final tid = key.substring(guestPrefix.length);
      final value = _box.get(key);
      if (value == null) continue;
      toMigrate['$targetPrefix$tid'] = Map<dynamic, dynamic>.from(value);
    }
    for (final entry in toMigrate.entries) {
      _box.put(entry.key, entry.value);
    }
    final guestKeys = _box.keys
        .where((k) => k is String && k.startsWith(guestPrefix))
        .toList();
    _box.deleteAll(guestKeys);
  }

  /// LRU 淘汰：仅按当前用户计数，超限删除最旧（`lastReadAt` 最小）。
  void _evictIfNeeded() {
    final keys = _box.keys.where(_belongsToUser).toList();
    if (keys.length <= maxRecords) return;
    keys.sort((a, b) {
      final at = (_box.get(a)?['lastReadAt'] as num?)?.toInt() ?? 0;
      final bt = (_box.get(b)?['lastReadAt'] as num?)?.toInt() ?? 0;
      return at.compareTo(bt);
    });
    final removeCount = keys.length - maxRecords;
    _box.deleteAll(keys.take(removeCount));
  }
}
