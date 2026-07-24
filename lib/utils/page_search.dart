/// 当页本地搜索：过滤已加载列表、在 HTML 文本节点中高亮匹配词。
///
/// 不走论坛 API，无提交冷却；仅对当前内存数据生效。
abstract final class PageSearch {
  /// 去掉首尾空白；空串表示「无查询」。
  static String normalizeQuery(String raw) => raw.trim();

  /// 大小写不敏感的子串匹配；[query] 为空时恒为 true。
  static bool matchesQuery(String haystack, String query) {
    final q = normalizeQuery(query);
    if (q.isEmpty) return true;
    return haystack.toLowerCase().contains(q.toLowerCase());
  }

  /// 任一 [fieldsOf] 字段命中即保留；空 query 返回原列表。
  static List<T> filterByQuery<T>(
    List<T> items,
    String query,
    Iterable<String> Function(T item) fieldsOf,
  ) {
    final q = normalizeQuery(query);
    if (q.isEmpty) return items;
    return [
      for (final item in items)
        if (fieldsOf(item).any((f) => matchesQuery(f, q))) item,
    ];
  }

  /// 仅在 HTML **标签外**文本中包裹 `<mark>`；不改动属性与标签名。
  ///
  /// 空 query 或无匹配时返回原串。已有 `<mark>` 不再二次包裹（简单跳过 mark 内容）。
  static String highlightHtml(String html, String query) {
    final q = normalizeQuery(query);
    if (q.isEmpty || html.isEmpty) return html;

    final escaped = RegExp.escape(q);
    final matchRe = RegExp(escaped, caseSensitive: false);
    final tokenRe = RegExp(
      r'<mark\b[^>]*>[\s\S]*?</mark>|<[^>]+>|[^<]+',
      caseSensitive: false,
    );

    final buf = StringBuffer();
    for (final m in tokenRe.allMatches(html)) {
      final token = m.group(0)!;
      if (token.startsWith('<')) {
        buf.write(token);
        continue;
      }
      buf.write(
        token.replaceAllMapped(matchRe, (hit) => '<mark>${hit[0]}</mark>'),
      );
    }
    return buf.toString();
  }
}
