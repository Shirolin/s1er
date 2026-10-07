import 'map_draft_codec.dart';

/// 新主题本地草稿，按版块保存，永不写入服务端。
///
/// 与回复 `compose_message_drafts`、编辑 `edit_post_drafts` 键空间互斥。
/// 存储形状与编解码见 [MapDraftCodec]。
abstract final class NewThreadDraftStore {
  static const settingsKey = 'new_thread_drafts';

  static Map<String, Map<String, Object?>> parse(Object? raw) =>
      MapDraftCodec.parse(raw);

  static Map<String, Object?>? read(
    Map<String, Map<String, Object?>> drafts,
    String fid,
  ) =>
      drafts[fid];

  /// 标题与正文皆空时删除条目，避免留下空草稿。
  static Map<String, Map<String, Object?>> upsert(
    Map<String, Map<String, Object?>> drafts,
    String fid, {
    required String subject,
    required String message,
    String? typeId,
  }) {
    return MapDraftCodec.upsert(
      drafts,
      fid,
      {
        'subject': subject,
        'message': message,
        if (typeId != null) 'typeId': typeId,
      },
      isEmpty: subject.trim().isEmpty && message.trim().isEmpty,
    );
  }

  static Map<String, Map<String, Object?>> remove(
    Map<String, Map<String, Object?>> drafts,
    String fid,
  ) =>
      MapDraftCodec.remove(drafts, fid);

  static Object? toStoreValue(Map<String, Map<String, Object?>> drafts) =>
      MapDraftCodec.toStoreValue(drafts);
}
