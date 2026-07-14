/// Discuz 引用助手返回的官方字段（`forum.php?mod=post&action=reply&repquote=`）。
class QuoteInfo {
  const QuoteInfo({
    required this.noticeAuthor,
    required this.noticeTrimStr,
  });

  /// 服务端编码的通知用户标识（非明文用户名）。
  final String noticeAuthor;

  /// 含 findpost 链接的引用 BBCode/HTML 片段。
  final String noticeTrimStr;

  /// 从 quote helper XML/HTML 中解析。
  static QuoteInfo? tryParse(String raw) {
    if (raw.trim().isEmpty) return null;

    final authorMatch = RegExp(
      r'''name=["']noticeauthor["']\s+value=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(raw);
    final trimMatch = RegExp(
      r'''name=["']noticetrimstr["']\s+value=["']([^"']*)["']''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);

    final author = authorMatch?.group(1)?.trim();
    final trimRaw = trimMatch?.group(1);
    if (author == null || author.isEmpty || trimRaw == null) return null;

    return QuoteInfo(
      noticeAuthor: author,
      noticeTrimStr: _unescapeHtml(trimRaw),
    );
  }

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }
}
