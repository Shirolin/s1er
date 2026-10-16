# 0002. 草稿编解码：三域收敛到 MapDraftCodec，私信独立

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/utils/map_draft_codec.dart`、`compose_message_draft.dart`、`new_thread_draft.dart`、`edit_post_draft.dart`、`pm_draft_store.dart`；[ADR-0001](0001-parser-transport-seam.md)

## 背景

四个撰写域各有一套本地草稿编解码：

- 回复 `ComposeMessageDraft`、新主题 `NewThreadDraftStore`、编辑 `EditPostDraftStore`：三者存储形状完全相同——`Map<String, Map<String, Object?>>`（`entryKey → payload`）。
- 私信 `PmDraftStore`：裸 `Map<String, String>`。

其中 `parse` / `remove` / `toStoreValue` 在**三个 payload-map 域逐字节相同**（`parse` 甚至逐字节相同两份）；`upsert` 的差异只在 payload 构造与「空则删」判断。重复导致：`parse` 的规范逻辑散落三处，改一处需记得同步其余。

## 决策

1. **新增 `MapDraftCodec`**，承载三个 payload-map 域共享的 `parse` / `upsert` / `remove` / `toStoreValue`。初稿列过 `read`，2026-10-07 复查撤销：各域 `read` 含 payload 类型转换与空判断等域特有语义，通用 `read` 只会是 `drafts[key]` 单行透传，故 `read` 保留在各域，codec 不收。`upsert` 增加 `isEmpty` 参数表达各域「空草稿不留存」策略（新主题：标题正文皆空则删；回复：正文空则删；编辑：始终保存）。
2. **三个 store 保留各自的公开 API 与命名**（`ComposeMessageDraft.parseStore/readMessage/removeEntry`、`NewThreadDraftStore.*`、`EditPostDraftStore.*`），内部委托 codec。调用点零改动。
3. **私信草稿不并入**：形状不同（裸 String map、无 `read`/`remove` 方法、调用点就地 `drafts.remove`），并入会引入特例污染接口；其重复量小，收益不足。
4. **域特有逻辑留在各域**：`ComposeMessageDraft.entryKey`（键规则）、`debounce`（防抖）、`readMessage`（message 类型与空判断）不进 codec。
5. **零行为变更**：纯结构搬移，公开签名不变。

## 结果

正面：

- 局部性：`parse` 规范逻辑只存一处；键空间语义集中可见。
- 接口收窄：三个 store 各只保留域特有部分（键规则 / payload 字段 / 空判断）。
- 删除两处逐字节重复的 `parse` 体与三处 `remove` / `toStoreValue`。

负面 / 代价：

- 多一层间接（store → codec）。可接受：codec 是纯函数集合，无状态。
- 若将来出现第五个 payload-map 域，应复用 codec 而非再写一套。

## 备选方案

- **抽象成「草稿域」接口 + 每域适配器类**：更"干净"，但要为每域写适配器，且现有调用点是静态风格，收益不足。
- **只合并 New/Edit 两个逐字节相同的**：Compose 仍留一份 `parse`，重复未根除。
- **把私信一并泛型化为 `MapDraftCodec<String>`**：形状差异（裸 map、无 read/remove）会迫使 codec 或调用点引入特例，已否决。
