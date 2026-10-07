/// Discuz HTML 实体解码的公共子集（纯 Dart，无依赖）。
///
/// 只解码各调用方都共有的 4 项（顺序固定）：
/// `&quot;` → `"`、`&#039;` → `'`、`&#39;` → `'`、`&nbsp;` → 空格。
///
/// `&amp;`、`&lt;`、`&gt;` 与标签剥离（`<[^>]+>`）的覆盖因数据来源而异，
/// 保留在各调用方原处（相对顺序不变），不要收拢到这里。
String decodeHtmlEntities(String text) {
  return text
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}
