/// 引用块跳转解析：从 quote 段 HTML/BBCode 中提取 findpost 链接。
///
/// 展示层契约：viewthread 返回的内容里需有 `ptid=`（或可用 [fallbackTid]），
/// 可选 `pid=`，供 `/thread/{tid}?pid=` 定位。
class QuoteJumpParser {
  QuoteJumpParser._();

  /// 优先 HTML `<a href>`，其次 BBCode `[url=…]`。
  static String? extractLink(String text) {
    final html = RegExp(
      r'<a\s+href="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(text);
    if (html != null) {
      return _unescape(html.group(1) ?? '');
    }

    final bbcode = RegExp(
      r'\[url=([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(text);
    if (bbcode != null) {
      return _unescape(bbcode.group(1) ?? '');
    }
    return null;
  }

  /// [fallbackTid]：链接缺 `ptid=` 时用当前帖 tid（配合 `pid=`）。
  static ({String tid, String? pid})? parsePostLink(
    String url, {
    String? fallbackTid,
  }) {
    final pidMatch = RegExp(r'pid=(\d+)').firstMatch(url);
    final ptidMatch = RegExp(r'ptid=(\d+)').firstMatch(url);
    final pid = pidMatch?.group(1);
    final ptid = ptidMatch?.group(1);

    if (ptid != null && ptid.isNotEmpty) {
      return (tid: ptid, pid: pid);
    }
    if (fallbackTid != null &&
        fallbackTid.isNotEmpty &&
        pid != null &&
        pid.isNotEmpty) {
      return (tid: fallbackTid, pid: pid);
    }
    return null;
  }

  static String _unescape(String url) {
    return url.replaceAll('&amp;', '&').replaceAll('&amp;amp;', '&');
  }
}

/// 将正文拆成普通段 / 引用段（`[quote]`、`[post]`、`reply_wrap`）。
class BbcodeQuoteSplitter {
  BbcodeQuoteSplitter._();

  static List<BbcodeQuoteSegment> split(String text) {
    final segments = <BbcodeQuoteSegment>[];
    final regex = RegExp(
      r'\[quote\](.*?)\[/quote\]'
      r'|\[post\](.*?)\[/post\]'
      r'|<div\s+class="reply_wrap">(.*?)</div>',
      dotAll: true,
      caseSensitive: false,
    );
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(
          BbcodeQuoteSegment(text.substring(lastEnd, match.start), false),
        );
      }
      final content = match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
      segments.add(BbcodeQuoteSegment(content, true));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(BbcodeQuoteSegment(text.substring(lastEnd), false));
    }

    return segments;
  }
}

class BbcodeQuoteSegment {
  const BbcodeQuoteSegment(this.text, this.isQuote);

  final String text;
  final bool isQuote;
}
