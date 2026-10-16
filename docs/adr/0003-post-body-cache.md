# 0003. 帖子正文解析缓存收敛到 PostBodyCache

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/utils/post_body_cache.dart`、`lib/widgets/bbcode_renderer.dart`；取代 `lib/utils/bbcode_cache.dart`

## 背景

`BbcodeRenderer`（`ConsumerWidget`）在 `_parseSegmentHtml` 里同时做三件事：拼装缓存键（正文 + `showImages` + `maxImagesPerPost` + `quoteDepth`）、查/写 LRU 缓存、调用 `BbcodeParser.parse`。其中「什么构成一次等价解析」是**策略**，却住在 widget 里。

`BbcodeCache` 只提供 LRU 存储与 `buildKey`，命中/未命中的分派仍散在 widget；且它**只有 `BbcodeRenderer` 一个消费者**。

## 决策

1. **以 `PostBodyCache` 取代 `BbcodeCache`**：把键类型（`PostBodyCacheKey`）、LRU 存储、以及命中/未命中的编排收敛到一个模块。对外接口为 `htmlFor({required PostBodyCacheKey key, required build})`，调用方以 `PostBodyCacheKey` 构造函数组装键（正文 + `showImages` + `maxImagesPerPost` + `quoteDepth`）；其中 `build` 是惰性解析回调（携带调用方的 `PostImageIndexCounter`）。
2. **模块不依赖 Flutter / Riverpod**：`showImages` / `maxImagesPerPost` 由调用方读设置后传入，模块不碰 provider。
3. **`htmlFor` 返回 `PostBodyCacheResult { html, wasCached }`**：保留「命中时需重放解析副作用」的既有语义——`BbcodeRenderer` 仅在 `wasCached` 为真时调用 `_advanceImageIndexFromHtml`（命中时解析未执行，图片 index 分配需重放；未命中时 parse 已就地赋值，不可重复推进）。行为与改前一致。
4. **不扩大范围**：`AuthorStyleStripper` / `PageSearch` / `PostImageUrls` 属渲染期（主题 / 高亮 / 图片来源），不进本模块。
5. **删除 `bbcode_cache.dart`**：其唯一消费者已迁移；通用 LRU 无第二调用方，按 YAGNI 不保留双份。

## 结果

正面：

- 局部性：缓存键与命中/未命中语义集中一处；键规则收敛于 PostBodyCacheKey，渲染层只传值不拼规则。
- 接口收窄：`BbcodeRenderer` 通过 `htmlFor` 一个入口拿解析结果。
- 删除 `BbcodeCache` 与 `_parseSegmentHtml` 里散落的 `get`/`put`。

负面 / 代价：

- `bbcode_cache.dart` 被删除，相关测试迁移为 `post_body_cache_test.dart`（覆盖 LRU 淘汰、键等价、命中/未命中、设置区分）。
- 图片计数仍在 widget 侧以「命中时反推」重放（未改）。若要彻底消除该补丁，需让解析结果自带段内图片数——留作独立的后续评估（动到跨段落计数的核心，风险较高）。

## 备选方案

- **抽 `PostBody` 值类型（raw + html + cacheKey），把 `_parseSegmentHtml` 换个家**：deletion test 为「just moves」，parse 仍在 `BbcodeParser`、cache 仍在 `BbcodeCache`，收益仅换址，且界面未真正收窄。已否决。
- **保留 `BbcodeCache` + 新增薄 `PostBodyCache` 分层**：多一层间接而无第二消费者，违 YAGNI。已否决。
