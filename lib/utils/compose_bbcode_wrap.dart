/// 用成对 BBCode 标签包裹选区（或在光标处插入空标签对）。
///
/// - 有选区：`openTag + selected + closeTag`，光标落在闭合标签后。
/// - 无选区：插入 `openTag + closeTag`，光标落在标签中间。
///
/// 不做邻接空格补齐（与 [insertSnippetPadded] 不同），以便格式标签紧贴选区。
({String text, int cursor}) wrapBbcodeSelection({
  required String text,
  required int start,
  required int end,
  required String openTag,
  required String closeTag,
}) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  final selected = text.substring(safeStart, safeEnd);
  final piece = '$openTag$selected$closeTag';
  final nextText = text.replaceRange(safeStart, safeEnd, piece);
  final cursor =
      selected.isEmpty ? safeStart + openTag.length : safeStart + piece.length;
  return (text: nextText, cursor: cursor);
}
