/// 每日签到本地缓存：SettingsStore 中按 uid + 本地日历日记录「今日已签」。
///
/// 仅服务 UI；真源仍是 Discuz 签到接口（无只读查询）。
abstract class DailyAttendanceStore {
  static const settingsKey = 'daily_attendance_signed';

  /// `YYYY-MM-DD`（本地时区日历日）。
  static String formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 从 SettingsStore 原始值解析 `{uid, date}`；无效则 null。
  static ({String uid, String date})? parse(Object? raw) {
    if (raw is! Map) return null;
    final uid = raw['uid']?.toString().trim() ?? '';
    final date = raw['date']?.toString().trim() ?? '';
    if (uid.isEmpty || date.isEmpty) return null;
    return (uid: uid, date: date);
  }

  static Map<String, String> payload({
    required String uid,
    required DateTime now,
  }) {
    return {'uid': uid, 'date': formatDate(now)};
  }

  /// 缓存是否表示 [uid] 在 [now] 的本地日历日已签到。
  static bool matches({
    required Object? raw,
    required String uid,
    required DateTime now,
  }) {
    final data = parse(raw);
    if (data == null) return false;
    if (data.uid != uid) return false;
    return data.date == formatDate(now);
  }
}
