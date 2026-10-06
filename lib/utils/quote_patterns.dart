/// 引语（quote）语法的单一出处：Discuz 引用块的 BBCode / HTML 结构模式。
///
/// 此前这些模式散落在 [QuoteBuilder] 与 [QuoteRecoveryHelper] 中，且存在
/// **相似但不同**的变体（严格头 vs 宽松头；仅 reply_wrap vs reply_wrap|blockquote）。
/// 集中到此，命名区分意图，避免「改一处忘了另一处」的漂移。
///
/// 注意：变体之间的差异是**有意的**，不是重复——见各模式注释与
/// [ADR-0006]。合并行为（而非仅集中模式）需以 golden 测试兜底，
/// 目前不做。
library;

abstract final class QuotePatterns {
  // ── BBCode ────────────────────────────────────────────────────────────────

  /// `[quote]…[/quote]` 正文（非贪婪）。
  ///
  /// 去嵌套用 `replaceAll`（忽略捕获组）；恢复取捕获组用 `allMatches`。
  static final bbcodeBody = RegExp(
    r'\[quote\]([\s\S]*?)\[/quote\]',
    caseSensitive: false,
  );

  /// 整串恰好被单个 `[quote]…[/quote]` 包裹（`parseClientQuote` 解包用）。
  static final bbcodeWrapped = RegExp(
    r'^\[quote\]([\s\S]*?)\[/quote\]\s*$',
    caseSensitive: false,
  );

  // ── 客户端引用头 `[size=N][url=…]作者[/url] 发表于 …[/size]` ───────────────

  /// **严格头**：要求合法日期，命中即得作者与正文起点。
  ///
  /// 用于 `parseClientQuote`：日期不合法时不命中，退回宽松的作者兜底。
  static final headerStrict = RegExp(
    r'^\[size=\d+\]\s*\[url=[^\]]+\]([^\[]*)\[/url\]\s*发表于\s*'
    r'(?:\d{4}-)?\d{1,2}-\d{1,2}\s*\d{2}:\d{2}(?::\d{2})?\s*\[/size\]\s*',
    caseSensitive: false,
  );

  /// **宽松头**：不校验日期，只剥掉 `[size=N]…发表于…[/size]`。
  ///
  /// 用于 `_cleanExtractedQuoteText`：恢复场景只需拿到正文，容忍任意日期格式。
  static final headerLoose = RegExp(
    r'^\[size=\d+\][\s\S]*?发表于[\s\S]*?\[/size\]\s*',
    caseSensitive: false,
  );

  /// 仅 `[url=…]作者[/url] 发表于` 段（严格头失败时的作者兜底）。
  static final headerUrlAuthor = RegExp(
    r'\[url=[^\]]+\]([^\[]+)\[/url\]\s*发表于\s*',
    caseSensitive: false,
  );

  /// 残留的收尾 `[/size]`（解析出半截头时常见）。
  static final trailingSizeTag = RegExp(r'^\[/size\]\s*', caseSensitive: false);

  // ── HTML ──────────────────────────────────────────────────────────────────

  /// `<div class="reply_wrap">…</div>`（去嵌套用，**仅 div**）。
  static final htmlReplyWrap = RegExp(
    r'<div\s+class="reply_wrap">[\s\S]*?</div>',
    caseSensitive: false,
  );

  /// `<div class="reply_wrap">` 或 `<blockquote>`（恢复匹配用，**含捕获组**）。
  ///
  /// 比 [htmlReplyWrap] 多匹配 `blockquote`——恢复需覆盖桌面模板的引用块。
  static final htmlQuoteBlock = RegExp(
    r'<(?:div\s+class="reply_wrap"|blockquote)[^>]*>([\s\S]*?)</(?:div|blockquote)>',
    caseSensitive: false,
  );

  /// `<div class="quote">…</div>` 引用头（恢复清理用）。
  static final htmlQuoteHeader = RegExp(
    r'^<div\s+class="quote">[\s\S]*?</div>\s*',
    caseSensitive: false,
  );
}
