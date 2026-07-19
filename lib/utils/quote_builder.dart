import '../models/post.dart';
import 'format_utils.dart';

/// 构建 Discuz 标准引用 BBCode，供回复预填使用。
class QuoteBuilder {
  QuoteBuilder._();

  static String buildQuoteBbcode({
    required Post post,
    required String tid,
  }) {
    final timeStr = formatDateTime(post.dateline);
    final body = _prepareQuoteBody(post.message);
    return '[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=${post.pid}&ptid=$tid]'
        '${post.author}[/url] 发表于 $timeStr[/size]\n'
        '$body\n'
        '[/quote]\n';
  }

  /// 将引用块与用户正文合并为预览串。
  ///
  /// **勿用于 `sendReply` 的 message**：提交通道为用户正文 + `noticetrimstr`
  ///（有快照时 trim 用 [buildQuoteBbcode]）。
  @Deprecated(
    'Submit via QuoteInfo + sendReply; message must not embed client quotes',
  )
  static String buildMessageWithQuote({
    required Post post,
    required String tid,
    required String userText,
    bool includeQuote = true,
  }) {
    if (!includeQuote) return userText.trim();
    final quote = buildQuoteBbcode(post: post, tid: tid);
    final trimmed = userText.trim();
    if (trimmed.isEmpty) return quote.trim();
    return '$quote$trimmed';
  }

  /// 引用预览摘要（纯文本，最多保留合理长度）。
  static String previewText(String message, {int maxLength = 120}) {
    final plain = stripHtmlTags(stripNestedQuotes(message)).trim();
    if (plain.length <= maxLength) return plain;
    return '${plain.substring(0, maxLength)}…';
  }

  /// Discuz 客户端引用头：`[size=2][url=…]作者[/url] 发表于 …[/size]`。
  ///
  /// 兼容同年无年号（`07-19 14:32`）与带年号（`2024-07-19 14:32`）。
  static final _clientQuoteHeader = RegExp(
    r'^\[size=\d+\]\s*\[url=[^\]]+\]([^\[]*)\[/url\]\s*发表于\s*'
    r'(?:\d{4}-)?\d{1,2}-\d{1,2}\s*\d{2}:\d{2}(?::\d{2})?\s*\[/size\]\s*',
    caseSensitive: false,
  );

  /// 解析编辑页前置 `[quote]`（或仅内层）为作者 + 纯文本摘要。
  ///
  /// 供编辑页引用条使用：与回复页引用条一样展示纯文本，不把原始 BBCode
  /// 直接塞进 [QuoteBlock]。
  static ({String? author, String preview}) parseClientQuote(String raw) {
    var text = raw.trim();
    final wrapped = RegExp(
      r'^\[quote\]([\s\S]*?)\[/quote\]\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (wrapped != null) {
      text = (wrapped.group(1) ?? '').trim();
    }

    String? author;
    final header = _clientQuoteHeader.firstMatch(text);
    if (header != null) {
      author = header.group(1)?.trim();
      if (author != null && author.isEmpty) author = null;
      text = text.substring(header.end);
    } else {
      final urlAuthor = RegExp(
        r'\[url=[^\]]+\]([^\[]+)\[/url\]\s*发表于\s*',
        caseSensitive: false,
      ).firstMatch(text);
      if (urlAuthor != null) {
        author = urlAuthor.group(1)?.trim();
        if (author != null && author.isEmpty) author = null;
      }
    }

    // 去掉残留的收尾 size（旧解析半截头时常见）。
    text =
        text.replaceFirst(RegExp(r'^\[/size\]\s*', caseSensitive: false), '');

    return (author: author, preview: previewText(text));
  }

  static String stripNestedQuotes(String text) {
    var result = text;
    result = result.replaceAll(
      RegExp(
        r'<div\s+class="reply_wrap">[\s\S]*?</div>',
        caseSensitive: false,
      ),
      '',
    );

    var previous = '';
    while (result != previous) {
      previous = result;
      result = result.replaceAll(
        RegExp(r'\[quote\][\s\S]*?\[/quote\]', caseSensitive: false),
        '',
      );
    }
    return result.trim();
  }

  static String stripHtmlTags(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String _prepareQuoteBody(String message) {
    return stripHtmlTags(stripNestedQuotes(message)).trim();
  }
}
