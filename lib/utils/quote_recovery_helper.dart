import '../models/post.dart';
import 'quote_builder.dart';

/// 从单个回复中提取的引用数据
class QuoteRecoveryItem {
  const QuoteRecoveryItem({
    required this.recoveredText,
    required this.sourceFloor,
    required this.sourceAuthor,
    required this.sourcePid,
  });

  /// 提取出的原始发言被引用文本片段
  final String recoveredText;

  /// 引用来源楼层号
  final int sourceFloor;

  /// 引用者用户名
  final String sourceAuthor;

  /// 引用来源 pid
  final String sourcePid;
}

/// 针对封禁楼层的引用恢复结果集合
class QuoteRecoveryResult {
  const QuoteRecoveryResult({
    this.quotes = const [],
  });

  final List<QuoteRecoveryItem> quotes;

  bool get hasQuotes => quotes.isNotEmpty;
  QuoteRecoveryItem? get firstQuote => quotes.isEmpty ? null : quotes.first;
  int get totalCount => quotes.length;
}

/// 从关联楼层中检索并恢复被封禁帖子发言的辅助类
class QuoteRecoveryHelper {
  QuoteRecoveryHelper._();

  /// 在给定的帖子列表 [allPosts] 中检索对 [targetPost] 的引用记录
  static QuoteRecoveryResult findQuotesForPost({
    required Post targetPost,
    required List<Post> allPosts,
  }) {
    if (targetPost.pid.isEmpty) {
      return const QuoteRecoveryResult();
    }

    final items = <QuoteRecoveryItem>[];
    final targetPid = targetPost.pid;
    final targetAuthor = targetPost.author.trim();

    for (final post in allPosts) {
      if (post.pid == targetPid) continue;
      final msg = post.message;
      if (msg.isEmpty) continue;

      final extracted = _extractQuoteTextForPid(
        msg: msg,
        targetPid: targetPid,
        targetAuthor: targetAuthor,
      );

      if (extracted != null && extracted.isNotEmpty) {
        items.add(
          QuoteRecoveryItem(
            recoveredText: extracted,
            sourceFloor: post.floor,
            sourceAuthor: post.author,
            sourcePid: post.pid,
          ),
        );
      }
    }

    return QuoteRecoveryResult(quotes: items);
  }

  /// 尝试从单个帖子的 [msg] 中提取对 [targetPid] / [targetAuthor] 的引用文字
  static String? _extractQuoteTextForPid({
    required String msg,
    required String targetPid,
    required String targetAuthor,
  }) {
    // 匹配 [quote]...[/quote]
    final bbcodeQuotes = RegExp(
      r'\[quote\]([\s\S]*?)\[/quote\]',
      caseSensitive: false,
    ).allMatches(msg);

    for (final match in bbcodeQuotes) {
      final inner = match.group(1) ?? '';
      if (_matchesTarget(inner, targetPid, targetAuthor)) {
        final text = _cleanExtractedQuoteText(inner);
        if (text.isNotEmpty) return text;
      }
    }

    // 匹配 HTML <div class="reply_wrap">...</div> 或 <blockquote...>...</blockquote>
    final htmlQuotes = RegExp(
      r'<(?:div\s+class="reply_wrap"|blockquote)[^>]*>([\s\S]*?)</(?:div|blockquote)>',
      caseSensitive: false,
    ).allMatches(msg);

    for (final match in htmlQuotes) {
      final inner = match.group(1) ?? '';
      if (_matchesTarget(inner, targetPid, targetAuthor)) {
        final text = _cleanExtractedQuoteText(inner);
        if (text.isNotEmpty) return text;
      }
    }

    return null;
  }

  static bool _matchesTarget(
    String quoteContent,
    String targetPid,
    String targetAuthor,
  ) {
    if (targetPid.isNotEmpty &&
        (quoteContent.contains('pid=$targetPid') ||
            quoteContent.contains('pid%3D$targetPid'))) {
      return true;
    }
    if (targetAuthor.isNotEmpty &&
        quoteContent.contains(targetAuthor) &&
        (quoteContent.contains('发表于') || quoteContent.contains('posted by'))) {
      return true;
    }
    return false;
  }

  static String _cleanExtractedQuoteText(String raw) {
    var text = raw;

    // 清理 Discuz 引用头 [size=2][url=...]author[/url] 发表于 ...[/size]
    text = text.replaceFirst(
      RegExp(
        r'^\[size=\d+\][\s\S]*?发表于[\s\S]*?\[/size\]\s*',
        caseSensitive: false,
      ),
      '',
    );

    // 清理 HTML 引用头
    text = text.replaceFirst(
      RegExp(
        r'^<div\s+class="quote">[\s\S]*?</div>\s*',
        caseSensitive: false,
      ),
      '',
    );

    text = QuoteBuilder.stripNestedQuotes(text);
    text = QuoteBuilder.stripHtmlTags(text);
    return text.trim();
  }
}
