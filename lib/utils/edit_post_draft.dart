/// 编辑帖本地草稿，按 pid 保存，永不写入服务端。
///
/// 与回复正文草稿 `compose_message_drafts`、新主题 `new_thread_drafts` 键空间互斥。
abstract class EditPostDraftStore {
  static const settingsKey = 'edit_post_drafts';

  static Map<String, Map<String, Object?>> parse(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, Map<String, Object?>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        result[entry.key.toString()] = Map<String, Object?>.from(
          (entry.value as Map)
              .map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    return result;
  }

  static Map<String, Object?>? read(
    Map<String, Map<String, Object?>> drafts,
    String pid,
  ) =>
      drafts[pid];

  static Map<String, Map<String, Object?>> upsert(
    Map<String, Map<String, Object?>> drafts,
    String pid, {
    required String subject,
    required String message,
    String? typeId,
    String? readPerm,
    String? leadingQuote,
    bool? includeQuote,
    List<String>? mediaTags,
    /// 与 [mediaTags] 一一对应的稳定 slot（`⟦图N⟧` 的 N）；缺省视为 1..n。
    List<int>? mediaSlots,
  }) {
    final next = parse(drafts);
    next[pid] = {
      'subject': subject,
      'message': message,
      if (typeId != null) 'typeId': typeId,
      if (readPerm != null) 'readPerm': readPerm,
      if (leadingQuote != null) 'leadingQuote': leadingQuote,
      if (includeQuote != null) 'includeQuote': includeQuote,
      if (mediaTags != null) 'mediaTags': mediaTags,
      if (mediaSlots != null) 'mediaSlots': mediaSlots,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    return next;
  }

  static Map<String, Map<String, Object?>> remove(
    Map<String, Map<String, Object?>> drafts,
    String pid,
  ) {
    final next = parse(drafts);
    next.remove(pid);
    return next;
  }

  static Object? toStoreValue(Map<String, Map<String, Object?>> drafts) {
    return drafts.isEmpty ? null : drafts;
  }
}
