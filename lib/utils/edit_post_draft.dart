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
    required String sourceSubject,
    required String sourceMessage,
    String? sourceTypeId,
    String? sourceReadPerm,
  }) {
    final next = parse(drafts);
    next[pid] = {
      'subject': subject,
      'message': message,
      if (typeId != null) 'typeId': typeId,
      if (readPerm != null) 'readPerm': readPerm,
      'sourceSubject': sourceSubject,
      'sourceMessage': sourceMessage,
      if (sourceTypeId != null) 'sourceTypeId': sourceTypeId,
      if (sourceReadPerm != null) 'sourceReadPerm': sourceReadPerm,
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
