# 0007. 阅读进度状态抽出为 ReadingProgressTracker；完整 ThreadOpenCoordinator 暂缓

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/utils/reading_progress_tracker.dart`、`lib/screens/thread_detail_screen.dart`

## 背景

一次架构评审提出把帖子详情页的「打开/滚动状态机」抽成 `ThreadOpenCoordinator`。
核对源码后发现：**可测的纯核心其实已经抽出**——

- 顶层纯函数 `shouldRecordReadingProgress` / `resolveFloorInPageForProgress` /
  `resolveThreadEndRefreshOutcome`（已被测试覆盖）；去重判断为 `ReadingProgressTracker.shouldWrite`
  实例方法（初稿曾名 `shouldWriteReadingProgressUpdate` 顶层函数，2026-10-07 复查定为实例方法，避免与实例状态分离）。
- `ScrollFloorNavigator`（`lib/utils/scroll_floor.dart`，278 行）；
- uid 切换副作用已由 `reading_history_coordinator` provider 承载。

留在 `_ThreadDetailScreenState` 的是 **render-bound 胶水**：`_postKeys:
List<GlobalKey>`（列表 ↔ `ScrollFloorNavigator` 的桥）、`setState` / `mounted` /
`WidgetsBinding.instance.endOfFrame`、`_swipeKey`、`_scrollFabVisibility`、
`ref.read(...).clearOpenScrollTarget()`。

**Deletion test**：抽完整 `ThreadOpenCoordinator`，它必须持有 `GlobalKey` 列表 +
`setState` 回调 + `mounted` 检查 + `endOfFrame` 等待 + 滚动控制器——一个**约等于
widget 的端口包**。结论：**just moves**，外加一层间接。

## 决策

1. **抽出 `ReadingProgressTracker`**（`lib/utils/`）：持有本次会话的进度状态
   （`hasRecordedInitialVisit` / `lastRecordedPage` / `lastRecordedFloorInPage` /
   `pageFloorMemory`），并给出 `shouldWrite`（去重）、`minProgressFloorInPage`
   （同页高水位下界）、`markRecorded`、`clearPageFloorMemory`。
2. **把纯解析与去重策略迁入同一模块**：`resolveFloorInPageForProgress`（顶层纯函数）迁入，
   去重判断收为 `ReadingProgressTracker.shouldWrite` 实例方法（初稿名 `shouldWriteReadingProgressUpdate`，复查定名）。屏幕改为引用之。
3. **render-bound 的 open/scroll 胶水留在屏幕**：`_consumeOpenScrollTarget` /
   `_applyOpenScrollTarget` / `_onScrollMetricsChanged` / `_scrollToTopImpl` 等
   与渲染树强耦合，不动。
4. **`shouldRecordReadingProgress` 留在屏幕**：它依赖 `AppSettings` / `AuthState`
   （provider 类型），不进纯模块。
5. **完整 `ThreadOpenCoordinator` 暂缓**：需要为 `GlobalKey` / `setState` /
   `mounted` / `endOfFrame` / 控制器造端口包，收益只是「换址 + 间接」，暂不做。

## 结果

正面：

- 局部性：进度去重与高水位策略集中一处，替换屏幕里 4 个散落字段。
- 可测：`ReadingProgressTracker` 独立单测（去重、下界、页内记忆），不再依赖
  widget 树。
- 屏幕少一层「字段 + 手写判断」的样板。

负面 / 代价：

- `shouldWrite` / `resolveFloorInPageForProgress` 的测试 import 从屏幕改到新模块。
- 测试 `thread_detail_progress_dedup_test` 的 import 随之更新（未用 `export`
  遮羞）。

## 备选方案

- **完整 `ThreadOpenCoordinator`**：端口包 ≈ widget，`just moves` + 间接；已否决
  （见决策 5）。
- **不抽、仅记录**：会继续保留 4 个散落字段与手写高水位逻辑；窄口子收益明确，
  故采纳窄抽取而非跳过。
