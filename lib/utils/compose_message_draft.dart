/// 回复正文草稿：SettingsStore JSON map 的编解码与 entry key。
///
/// 与内存里的 [ComposeDraftStore]（引用目标帖快照）并存，勿混用。
abstract class ComposeMessageDraft {
  static const settingsKey = 'compose_message_drafts';
  static const Duration debounce = Duration(milliseconds: 400);

  /// `{tid}` 或 `{tid}:{reppost}`。
  static String entryKey({required String tid, String? reppost}) {
    final pid = reppost?.trim();
    if (pid == null || pid.isEmpty) return tid;
    return '$tid:$pid';
  }

  /// 将 SettingsStore 原始值规范为 `entryKey → payload map`。
  static Map<String, Map<String, Object?>> parseStore(Object? raw) {
    if (raw is! Map) return {};
    final out = <String, Map<String, Object?>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map) {
        out[key] = Map<String, Object?>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return out;
  }

  /// 读取某 entry 的 message；无效或空则返回 null。
  static String? readMessage(
    Map<String, Map<String, Object?>> drafts,
    String key,
  ) {
    final payload = drafts[key];
    if (payload == null) return null;
    final message = payload['message'];
    if (message is! String) return null;
    if (message.trim().isEmpty) return null;
    return message;
  }

  /// 写入 / 更新一条草稿。
  static Map<String, Map<String, Object?>> upsert(
    Map<String, Map<String, Object?>> drafts,
    String key,
    String message, {
    DateTime? updatedAt,
  }) {
    final next = Map<String, Map<String, Object?>>.from(
      drafts.map((k, v) => MapEntry(k, Map<String, Object?>.from(v))),
    );
    next[key] = {
      'message': message,
      'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
    return next;
  }

  /// 删除一条草稿。
  static Map<String, Map<String, Object?>> removeEntry(
    Map<String, Map<String, Object?>> drafts,
    String key,
  ) {
    if (!drafts.containsKey(key)) return drafts;
    final next = Map<String, Map<String, Object?>>.from(
      drafts.map((k, v) => MapEntry(k, Map<String, Object?>.from(v))),
    );
    next.remove(key);
    return next;
  }

  /// 供 SettingsStore.put：空 map 返回 null 以清除整键。
  static Object? toStoreValue(Map<String, Map<String, Object?>> drafts) {
    if (drafts.isEmpty) return null;
    return drafts.map((k, v) => MapEntry(k, Map<String, Object?>.from(v)));
  }
}
