/// 回复正文中的 `[img]url[/img]` 解析与编辑辅助。
library;

final _imgTagPattern = RegExp(
  r'\[img\](.*?)\[/img\]',
  caseSensitive: false,
  dotAll: true,
);

/// 按出现顺序提取 URL（去重保序：首次出现为准）。
List<String> extractImgUrls(String text) {
  final seen = <String>{};
  final urls = <String>[];
  for (final match in _imgTagPattern.allMatches(text)) {
    final url = match.group(1)?.trim() ?? '';
    if (url.isEmpty || seen.contains(url)) continue;
    seen.add(url);
    urls.add(url);
  }
  return urls;
}

/// 移除正文中所有指向 [url] 的 `[img]…[/img]`。
String removeImgTag(String text, String url) {
  final tag = '[img]$url[/img]';
  return text.replaceAll(tag, '');
}

/// Chip 可见短标签。
String displayLabelForIndex(int index) => '图片 ${index + 1}';

/// 从 URL path 取文件名，供 Tooltip。
String filenameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final seg = uri?.pathSegments;
  if (seg != null && seg.isNotEmpty) {
    final name = seg.last.trim();
    if (name.isNotEmpty) {
      try {
        return Uri.decodeComponent(name);
      } on ArgumentError {
        return name;
      }
    }
  }
  return url;
}

/// 在光标处插入 `[img]url[/img]`，必要时前后补空格避免与文字粘连。
({String text, int cursor}) insertImgTagAt({
  required String text,
  required int start,
  required int end,
  required String url,
}) {
  final tag = '[img]$url[/img]';
  return insertSnippetPadded(
    text: text,
    start: start,
    end: end,
    snippet: tag,
  );
}

/// 在光标处插入片段；若与邻接非空白字符相贴则补空格。
({String text, int cursor}) insertSnippetPadded({
  required String text,
  required int start,
  required int end,
  required String snippet,
}) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  var piece = snippet;
  var cursorOffset = snippet.length;

  if (safeStart > 0) {
    final prev = text[safeStart - 1];
    if (!_isWhitespace(prev) && !_isWhitespace(snippet[0])) {
      piece = ' $piece';
      cursorOffset += 1;
    }
  }
  if (safeEnd < text.length) {
    final next = text[safeEnd];
    if (!_isWhitespace(next) && !_isWhitespace(piece[piece.length - 1])) {
      piece = '$piece ';
    }
  }

  final nextText = text.replaceRange(safeStart, safeEnd, piece);
  return (text: nextText, cursor: safeStart + cursorOffset);
}

/// 表情实体插入：后接中文/字母数字时补尾随空格。
({String text, int cursor}) insertEmoticonEntity({
  required String text,
  required int start,
  required int end,
  required String entity,
}) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  var piece = entity;
  var cursorOffset = entity.length;

  if (safeEnd < text.length && _needsTrailingSpace(text[safeEnd])) {
    piece = '$piece ';
  }

  final nextText = text.replaceRange(safeStart, safeEnd, piece);
  return (text: nextText, cursor: safeStart + cursorOffset);
}

bool _isWhitespace(String ch) =>
    ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';

bool _needsTrailingSpace(String next) {
  if (_isWhitespace(next)) return false;
  if (RegExp(r'[A-Za-z0-9]').hasMatch(next)) return true;
  final code = next.runes.first;
  // CJK Unified Ideographs + common CJK punctuation-adjacent letters
  return code >= 0x4E00 && code <= 0x9FFF;
}

/// 最近表情：去重顶置，最多 [max]。
List<String> pushRecentEmoticon(
  List<String> current,
  String entity, {
  int max = 24,
}) {
  final next = <String>[entity, ...current.where((e) => e != entity)];
  if (next.length > max) {
    return next.sublist(0, max);
  }
  return next;
}
