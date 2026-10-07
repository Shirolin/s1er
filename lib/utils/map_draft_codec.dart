/// 草稿 map 的通用编解码：`SettingsStore` 原始值 ⇄ `entryKey → payload map`。
///
/// 三个撰写域（回复 `compose_message_draft`、新主题 `new_thread_draft`、编辑
/// `edit_post_draft`）共用同一存储形状：`Map<String, Map<String, Object?>>`。
/// 它们的 parse / remove / toStoreValue 逐字节相同，upsert 的差异只在 payload
/// 构造与空判断，故收敛到此模块，各域只提供策略。
///
/// 私信草稿（`PmDraftStore`）形状不同（裸 `Map<String, String>`），不并入。
abstract final class MapDraftCodec {
  /// 将 `SettingsStore` 原始值规范为 `entryKey → payload map`。
  ///
  /// 非 Map 的原始值、以及 payload 非 Map 的条目一律丢弃。
  static Map<String, Map<String, Object?>> parse(Object? raw) {
    if (raw is! Map) return {};
    final out = <String, Map<String, Object?>>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is Map) {
        out[entry.key.toString()] = Map<String, Object?>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return out;
  }

  /// 写入 / 更新一条草稿。
  ///
  /// [isEmpty] 为真时删除条目而非写入，供各域表达「空草稿不留存」。
  static Map<String, Map<String, Object?>> upsert(
    Map<String, Map<String, Object?>> drafts,
    String key,
    Map<String, Object?> payload, {
    required bool isEmpty,
  }) {
    final next = Map<String, Map<String, Object?>>.from(drafts);
    if (isEmpty) {
      next.remove(key);
      return next;
    }
    next[key] = payload;
    return next;
  }

  /// 删除某条草稿（不存在则为无操作），返回新 map，不改动入参。
  static Map<String, Map<String, Object?>> remove(
    Map<String, Map<String, Object?>> drafts,
    String key,
  ) {
    final next = Map<String, Map<String, Object?>>.from(drafts);
    next.remove(key);
    return next;
  }

  /// 序列化回 `SettingsStore`；空则返回 `null`（清除该 key）。
  static Object? toStoreValue(Map<String, Map<String, Object?>> drafts) {
    return drafts.isEmpty ? null : drafts;
  }
}
