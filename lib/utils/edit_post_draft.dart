import 'map_draft_codec.dart';

/// 编辑帖本地草稿，按 pid 保存，永不写入服务端。
///
/// 与回复正文草稿 `compose_message_drafts`、新主题 `new_thread_drafts` 键空间互斥。
/// 存储形状与编解码见 [MapDraftCodec]。
abstract final class EditPostDraftStore {
  static const settingsKey = 'edit_post_drafts';

  static Map<String, Map<String, Object?>> parse(Object? raw) =>
      MapDraftCodec.parse(raw);

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
    return MapDraftCodec.upsert(
      drafts,
      pid,
      {
        'subject': subject,
        'message': message,
        if (typeId != null) 'typeId': typeId,
        if (readPerm != null) 'readPerm': readPerm,
        if (leadingQuote != null) 'leadingQuote': leadingQuote,
        if (includeQuote != null) 'includeQuote': includeQuote,
        if (mediaTags != null) 'mediaTags': mediaTags,
        if (mediaSlots != null) 'mediaSlots': mediaSlots,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      // 编辑草稿始终保存（即使正文暂空），以便恢复服务器基线字段。
      isEmpty: false,
    );
  }

  static Map<String, Map<String, Object?>> remove(
    Map<String, Map<String, Object?>> drafts,
    String pid,
  ) =>
      MapDraftCodec.remove(drafts, pid);

  static Object? toStoreValue(Map<String, Map<String, Object?>> drafts) =>
      MapDraftCodec.toStoreValue(drafts);
}
