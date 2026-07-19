/// 新主题本地草稿，按版块保存，永不写入服务端。
///
/// 与回复 `compose_message_drafts`、编辑 `edit_post_drafts` 键空间互斥。
abstract class NewThreadDraftStore {
  static const settingsKey = 'new_thread_drafts';

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
    String fid,
  ) {
    return drafts[fid];
  }

  /// 标题与正文皆空时删除条目，避免留下空草稿。
  static Map<String, Map<String, Object?>> upsert(
    Map<String, Map<String, Object?>> drafts,
    String fid, {
    required String subject,
    required String message,
    String? typeId,
  }) {
    final next = parse(drafts);
    if (subject.trim().isEmpty && message.trim().isEmpty) {
      next.remove(fid);
      return next;
    }
    next[fid] = {
      'subject': subject,
      'message': message,
      if (typeId != null) 'typeId': typeId,
    };
    return next;
  }

  static Map<String, Map<String, Object?>> remove(
    Map<String, Map<String, Object?>> drafts,
    String fid,
  ) {
    final next = parse(drafts);
    next.remove(fid);
    return next;
  }

  static Object? toStoreValue(Map<String, Map<String, Object?>> drafts) {
    return drafts.isEmpty ? null : drafts;
  }
}
