import 'post_signature.dart';

/// 编辑帖时把服务器原文拆成「前置引用 / 用户正文」，小尾巴另行剥离。
///
/// 约定对齐回复页：输入框只含用户正文；引用用 [QuoteBlock] 展示；
/// 提交时再 `compose` + [PostSignature.appendIfEnabled]。
class EditPostMessageParts {
  const EditPostMessageParts({
    this.leadingQuote,
    required this.body,
    this.hadClientSignature = false,
  });

  /// 含外层 `[quote]…[/quote]`（可带尾随换行）；无前置引用时为 null。
  final String? leadingQuote;

  /// 去掉前置引用与客户端小尾巴后的正文。
  final String body;

  /// 原文末尾是否匹配过客户端小尾巴（供调试 / 测试）。
  final bool hadClientSignature;

  bool get hasLeadingQuote =>
      leadingQuote != null && leadingQuote!.trim().isNotEmpty;

  /// 给 [QuoteBlock] 用的内层内容（不含外层 quote 标签）。
  String? get quoteInner {
    final raw = leadingQuote?.trim();
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(
      r'\[quote\]([\s\S]*?)\[/quote\]',
      caseSensitive: false,
    ).firstMatch(raw);
    return (match?.group(1) ?? raw).trim();
  }

  static EditPostMessageParts split(String raw) {
    final withoutSig = PostSignature.stripTrailing(raw);
    final hadSig = withoutSig != raw.trimRight();

    final match = RegExp(
      r'^\s*(\[quote\][\s\S]*?\[/quote\])\s*',
      caseSensitive: false,
    ).firstMatch(withoutSig);
    if (match == null) {
      return EditPostMessageParts(
        body: withoutSig.trimRight(),
        hadClientSignature: hadSig,
      );
    }

    return EditPostMessageParts(
      leadingQuote: match.group(1),
      body: withoutSig.substring(match.end).trimRight(),
      hadClientSignature: hadSig,
    );
  }

  /// 拼回「引用 + 正文」（不含小尾巴）。
  static String compose({
    String? leadingQuote,
    required String body,
  }) {
    final trimmedBody = body.trimRight();
    final quote = leadingQuote?.trim();
    if (quote == null || quote.isEmpty) return trimmedBody;
    if (trimmedBody.isEmpty) return quote;
    // Discuz 入库的引用块后通常已有换行；再补一层避免粘连。
    final gap = quote.endsWith('\n') ? '' : '\n';
    return '$quote$gap$trimmedBody';
  }
}
