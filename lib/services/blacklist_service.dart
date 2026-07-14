import '../models/blacklist_record.dart';
import 'app_local_data.dart';

/// 本地黑名单服务：设备级 CRUD（主键为被拉黑用户 uid）。
class BlacklistService {
  BlacklistService(this._local);

  final AppLocalData _local;

  List<BlacklistRecord> getAll() {
    final entries = List<BlacklistRecord>.of(_local.blacklist.values);
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  BlacklistRecord? get(String uid) {
    if (uid.isEmpty) return null;
    return _local.blacklist[uid];
  }

  bool isBlocked(String uid) => get(uid) != null;

  bool hasScope(String uid, String scope) {
    final entry = get(uid);
    if (entry == null) return false;
    return entry.hasScope(scope);
  }

  /// 加入或更新黑名单。返回写入后的条目；uid 为空则忽略。
  BlacklistRecord? upsert({
    required String uid,
    String username = '',
    String reason = '',
    List<String> scope = BlacklistRecord.defaultScopes,
    int? createdAt,
  }) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return null;

    final existing = _local.blacklist[trimmed];
    final entry = BlacklistRecord(
      uid: trimmed,
      username: username.trim().isNotEmpty
          ? username.trim()
          : (existing?.username ?? ''),
      createdAt: createdAt ??
          existing?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
      reason: reason,
      scope: BlacklistRecord.normalizeScopes(scope),
    );
    _local.putBlacklistRecord(entry);
    return entry;
  }

  void remove(String uid) {
    if (uid.isEmpty) return;
    _local.deleteBlacklistRecord(uid);
  }

  Future<void> clearAll() => _local.clearBlacklist();
}
