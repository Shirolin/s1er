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
  /// **勿用于 `sendReply` 的 message**：提交通道只发用户正文 + 官方 `noticetrimstr`。
  @Deprecated(
      'Submit via QuoteInfo + sendReply; message must not embed client quotes',)
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
