import 'bbcode_parser.dart';
import 'quote_builder.dart';

/// 将楼层 `message`（BBCode / HTML 混排）转为可读纯文本，供复制全文使用。
abstract final class PostPlainText {
  static final _br = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final _blockEnd = RegExp(
    r'</(?:p|div|blockquote|pre|li|h[1-6])>',
    caseSensitive: false,
  );
  static final _hr = RegExp(r'<hr\s*/?>', caseSensitive: false);
  static final _postImage = RegExp(
    r'<span[^>]*class="[^"]*post-image[^"]*"[^>]*(?:/>|>.*?</span>)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _dataFull = RegExp(r'data-full="([^"]*)"');
  static final _dataPreview = RegExp(r'data-preview="([^"]*)"');
  static final _emoticonSpan = RegExp(
    r'<span[^>]*class="[^"]*emoticon[^"]*"[^>]*>.*?</span>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _dataCode = RegExp(r'data-code="([^"]*)"');
  static final _excessNewlines = RegExp(r'\n{3,}');

  /// 保留引用正文与链接可见文字；图片落成 URL；表情落成 `[code]`。
  static String fromMessage(String message) {
    if (message.trim().isEmpty) return '';

    var html = BbcodeParser.parse(message);
    html = html.replaceAll(_br, '\n');
    html = html.replaceAllMapped(_postImage, (m) {
      final tag = m.group(0)!;
      final full = _dataFull.firstMatch(tag)?.group(1);
      final preview = _dataPreview.firstMatch(tag)?.group(1);
      final url = (full != null && full.isNotEmpty) ? full : preview;
      return url == null || url.isEmpty ? '' : '\n$url\n';
    });
    html = html.replaceAllMapped(_emoticonSpan, (m) {
      final code = _dataCode.firstMatch(m.group(0)!)?.group(1);
      return code == null || code.isEmpty ? '' : '[$code]';
    });
    html = html.replaceAll(_blockEnd, '\n');
    html = html.replaceAll(_hr, '\n');

    final plain = QuoteBuilder.stripHtmlTags(html);
    return plain.replaceAll(_excessNewlines, '\n\n').trim();
  }
}
