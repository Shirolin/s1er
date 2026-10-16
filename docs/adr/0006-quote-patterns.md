# 0006. 引语语法集中到 QuotePatterns；完整 QuoteBlock 合并暂缓

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/utils/quote_patterns.dart`、`quote_builder.dart`、`quote_recovery_helper.dart`

## 背景

引语（quote）的 BBCode / HTML 结构模式散落在 `QuoteBuilder` 与
`QuoteRecoveryHelper` 中。核对后发现：这些模式**相似但不相同**，服务不同契约：

| 模式 | 位置 | 差异 |
|:---|:---|:---|
| `[quote]…[/quote]` | builder 去嵌套（无捕获）/ recovery 匹配（含捕获） | 内容匹配一致，捕获/用法不同 |
| 客户端引用头 | builder **严格**（要求合法日期）/ recovery **宽松**（不校验日期） | 行为不同 |
| HTML 引用块 | builder **仅** `div.reply_wrap` / recovery `div.reply_wrap \| blockquote` | 覆盖范围不同 |

此外 `QuoteRecoveryHelper` **已委托** `QuoteBuilder.stripNestedQuotes` /
`stripHtmlTags`（去嵌套 / 去 HTML 并未重复）。

即：重复是**语义变体**，不是逐字拷贝。

## 决策

1. **集中模式到 `QuotePatterns`**（`lib/utils/`）：`bbcodeBody` / `bbcodeWrapped`
   / `headerStrict` / `headerLoose` / `headerUrlAuthor` / `trailingSizeTag` /
   `htmlReplyWrap` / `htmlQuoteBlock` / `htmlQuoteHeader`。`QuoteBuilder` 与
   `QuoteRecoveryHelper` 改为引用之。
2. **保留变体的有意差异**：严格头与宽松头、`htmlReplyWrap` 与 `htmlQuoteBlock`
   各自**具名并注释**，不合并行为。集中是为了「改一处不必记得其它两处」，
   同时让差异显式可见。
3. **新增 `quote_patterns_test.dart`**：直接锁定各变体的**有意差异**（如宽松头
   命中严格头拒绝的畸形日期；`htmlQuoteBlock` 多匹配 `blockquote`），防止将来
   被误认为重复而合并。
4. **完整 `QuoteBlock` 合并暂缓**：把 raw 引语解析为 `(author, dateStr, body,
   link)` 并统一头部，价值有，但需协调严格/宽松头的行为——而引语恢复是用户可见
   功能（还原被封禁楼层的原话），现有测试样例有限。合并须先以 golden 测试兜底，
   风险与成本高于本轮其它重构，故记录在案、留待有测试兜底时再评估。

## 结果

正面：

- 局部性：引语语法（含变体差异）集中一处，漂移风险消除。
- 变体差异有测试锁定，且测试本身即文档。

负面 / 代价：

- 仍是「模式集中 + 各调用点保留行为」，不是单一解析器；`QuoteBlock` 的更深合并
  未做（见决策 4）。

## 备选方案

- **完整 `QuoteBlock`（解析 + 产出 BBCode，统一头部）**：价值更高，但需协调
  严格/宽松头并为 builder **与** recovery 补 golden 测试；行为漂移会伤及引语
  恢复（用户可见）。暂缓，理由见决策 4。
- **不集中，仅补注释**：仍会漂移（三处正则各自演化）。已否决。
