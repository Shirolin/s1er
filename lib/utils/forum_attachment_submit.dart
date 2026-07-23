/// 论坛附件提交辅助：收集 `[attachimg]` aid，并生成 `attachnew` 字段。
library;

final _attachImgRegex = RegExp(
  r'\[attachimg\](\d+)\[/attachimg\]',
  caseSensitive: false,
);

final _forumImgAidRegex = RegExp(
  r'\[img\](.*?forum\.php\?.*?(?:[?&]|&amp;)aid=(\d+).*?)\[/img\]',
  caseSensitive: false,
  dotAll: true,
);

/// 从正文收集论坛附件 aid（保序去重）。
Set<String> collectForumAttachmentIds(String? message) {
  if (message == null || message.isEmpty) return const {};
  final ids = <String>{};
  for (final match in _attachImgRegex.allMatches(message)) {
    final aid = match.group(1)?.trim() ?? '';
    if (aid.isNotEmpty) ids.add(aid);
  }
  for (final match in _forumImgAidRegex.allMatches(message)) {
    final aid = match.group(2)?.trim() ?? '';
    if (aid.isNotEmpty) ids.add(aid);
  }
  return ids;
}

bool hasForumAttachments(String? message) =>
    collectForumAttachmentIds(message).isNotEmpty;

/// 把正文里的 `forum.php?…aid=N` 形式 `[img]` 规范成 `[attachimg]`。
String normalizeForumAttachmentMessage(String? message) {
  if (message == null || message.isEmpty) return message ?? '';
  return message.replaceAllMapped(_forumImgAidRegex, (match) {
    final aid = match.group(2) ?? '';
    return '[attachimg]$aid[/attachimg]';
  });
}

/// 为网页发帖表单追加 `attachnew[aid][description|readperm]`。
void appendAttachNewFields(
  Map<String, String> fields,
  Iterable<String> attachmentIds,
) {
  for (final aid in attachmentIds) {
    final trimmed = aid.trim();
    if (trimmed.isEmpty) continue;
    fields['attachnew[$trimmed][description]'] = '';
    fields['attachnew[$trimmed][readperm]'] = '';
  }
}
