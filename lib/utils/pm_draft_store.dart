abstract class PmDraftStore {
  static const settingsKey = 'pm_message_drafts';

  static Map<String, String> parse(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.value is String && entry.value.toString().trim().isNotEmpty) {
        result[entry.key.toString()] = entry.value.toString();
      }
    }
    return result;
  }

  static Map<String, String> upsert(
    Map<String, String> drafts,
    String touid,
    String message,
  ) {
    final next = Map<String, String>.from(drafts);
    if (message.trim().isEmpty) {
      next.remove(touid);
    } else {
      next[touid] = message;
    }
    return next;
  }

  static Object? toStoreValue(Map<String, String> drafts) {
    return drafts.isEmpty ? null : drafts;
  }
}
