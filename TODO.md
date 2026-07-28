# S1er TODO List

## 待实现功能 (Features to Implement)

### 1. 多楼层分享功能 (Multi-Floor Share)
*状态: 已实现 (Done — 2026-07-22)*

**定案:**
- 跨页可选：点选拷贝 `{Post, displayFloor}` 快照，翻页保留；退出多选 / 离开帖子清空
- 入口：楼层菜单「多选分享」预选当前楼；AppBar「取消」；底栏「生成分享图」
- 捕获：统一 `List<ShareFloorData>`；矮卡单次 `toImage`；多选或超阈值按楼分块 → Isolate 无损拼接 → 只 encode 一次
- 上限：层数软顶 10 + 捕获像素硬顶（见 `S1Constants`）；失败提示少选或降清晰度
- 排序：按 `displayFloor` 升序；含 `#1` 时附带 poll

**长期优化 (视用户反馈):**
- ~~单楼仍超 GPU 纹理时，探索楼内按高度再切块~~ → 已实现「设置 → 分享 → 高级导出」（楼内滚动视口切片 + 放宽像素硬顶；默认关）
- ~~PC / 桌面端进一步提高分享限制~~ → 已实现 **仅高级模式** 平台分级：`ShareCaptureLimits`（mobile / desktop / web 不同硬顶与 strip 高度）+ `VerticalRgbaComposer` 增量拼接降 RAM 峰值；普通分享不变

### 2. 富文本编辑功能完善 (Rich Text Editor Enhancements)
*状态: 进行中 (In Progress)*

**功能描述:**
完善发帖、回帖、编辑帖子时的富文本相关功能，提供更好的排版和输入体验。

**实现计划:**
- **基础排版支持**: ~~加粗 / 斜体 / 下划线 / 删除线~~；~~预设色 `[color=#RRGGBB]`~~；字号 `[size]` 档位仍规划中（本轮不做自由取色 / backcolor）。
- **媒体与超链接**: 完善插入图片（论坛附件默认 + 外链图床）、插入超链接的交互体验。
- **引用与代码块**: ~~快捷插入引用块、代码块~~。
- **S1 特色功能**: 麻将脸面板；~~普通 `[hide]` + 积分隐藏 `[hide=N]`~~；剧透等其它标签仍规划中。
- **预览功能**: 发帖/回复前预览（compose 本地 parser；读帖仍以服务端 HTML 为准）。

### 3. 支持用户导入自定义字体 (Custom Font Import)
*状态: 规划中 (Planned)*

**功能描述:**
允许用户从设备本地导入自定义字体文件（.ttf 或 .otf），替换全应用的默认字体显示。

**可行性评估与实现方案:**
- **技术底座**: 完全可行。Flutter 原生提供了 `FontLoader` API，支持在运行时动态加载二进制文件并注册为 FontFamily，**无需引入第三方复杂库**。
- **多端可行性**:
  - **移动/桌面端 (Android/iOS/Windows/macOS/Linux)**: 完美支持。利用现有的 `file_selector` 库选择字体，拷贝到本地应用沙盒中持久化。每次冷启动时异步读取并通过 `FontLoader` 加载。
  - **Web 端**: 技术上能读取并加载，但由于 Web 沙盒持久化大体积字体文件（常 10MB+）较重，且 Web 用户可用浏览器插件解决，建议 Web 端做降级屏蔽或仅做单次会话有效。
- **实现计划**:
  1. 在"外观设置"页增加"自定义字体"管理菜单（导入字体、清除恢复默认）。
  2. 封装 `FontService`，处理字体文件的读取、沙盒拷贝和应用初始化时的 `FontLoader.load()`。
  3. 将加载成功的字体名称动态注入到 `AppTheme` 的 `ThemeData.fontFamily` 中以覆盖全应用。

### 4. 帖子详情页无限滚动兼容开关 (Infinite Scroll Toggle)
*状态: 规划中 (Planned)*

**功能描述:**
在设置中添加「无限滚动」开关，开启后帖子详情页从「左右滑动翻页」切换为「滑到底部自动加载下一页」。关闭时恢复当前的分页模式。

**改动范围（对应文件）：**

- **设置层** (`lib/providers/settings_provider.dart` + `lib/widgets/settings/browsing_settings_section.dart`):
  - `AppSettings` 新增 `infiniteScrollEnabled` bool 字段（默认 `false`）
  - `SettingsNotifier` 新增 `setInfiniteScrollEnabled()` + persist
  - 浏览行为设置页加一个 `SwitchListTile`

- **Provider 层** (`lib/providers/post_provider.dart`):
  - 新增 `loadNextPage()`：取 `currentPage + 1` 调 API，结果 append 到 `posts` 列表
  - `goToPage()` 在无限模式下若目标页未加载则先加载再合并
  - `filterByAuthor()` / `clearFilter()` 在两种模式下均重置列表

- **UI 层** (`lib/screens/thread_detail_screen.dart`):
  - 将当前 `build()` 的分页渲染提取为 `_buildPagination(PostListState)`
  - 新增 `_buildInfiniteScroll(PostListState)`：单 `ListView` + `ScrollController` + `NotificationListener` 触底加载
  - 底部 loading spinner / retry 提示
  - FAB 适配：无限模式下替换 `onGoToNextPage` 为「到底加载更多」
  - `_goToPage()` 在无限模式下改为 `scrollToFloor()` 跳转

- **边缘适配**:
  - `lib/services/reading_history_service.dart`：`updateProgress` 的 `page` 参数用 `pageForFloor(absoluteFloor)` 反推
  - 大帖内存保护：`posts.length` 超上限（如 10 页 = 400）时卸载最早页
  - 只看作者模式下 append 逻辑验证

- **测试**:
  - 新增无限模式单元测试（`loadNextPage` append、`totalPages` 边界、filter 重置）
  - 阅读历史 / 路由恢复（`?page=N`、`resume=1`）双模式回归

### 5. 手动阅读书签 (Manual Read Progress Bookmark)
*状态: 规划中 (Planned)*

**功能描述:**
对标 S1-NEXT 菜单「保存进度 / 读取进度」：用户可主动钉住当前阅读位置，与自动 `recordReadingHistory` 并存。

**实现要点:**
- 详情页 AppBar 菜单：保存当前进度、读取已保存进度
- 存储可复用 `reading_histories` 或独立书签表（需定案）；与自动续读高水位逻辑解耦
- 设置项：是否显示菜单入口（可选）

**依赖:** 现有 `lastReadFloor` + `ScrollToFloor` 楼级恢复已可用；书签是显式用户动作，不替代自动记录。

### 6. 帖内 QuickSideBar (In-Page Floor Quick Jump)
*状态: 规划中 (Planned)*

**难度:** 中等（非 trivial）

**功能描述:**
右侧贴边楼层快跳条，作用域为**当前页**内（非跨页）；对标 S1-NEXT `QuickSideBarView`。

**实现要点:**
- 新 widget（如 `lib/widgets/quick_side_bar.dart`）：右侧窄条 + 拖拽时楼层 Tips
- 采样：前 10 楼全显示，之后隔楼显示，避免过密
- 拖拽 → `ScrollFloorNavigator.scrollToIndex`（复用 `_postKeys`）
- 设置开关（`browsing_settings_section`）；默认关
- **手势隔离**：与 `S1SwipePagination` 横滑、`S1FabLayout` 底栏 FAB 避让（窄 hit 区、仅纵向拖拽）

**不做:** 跨页楼层索引、第三方 alphabet 库硬套。

### 7. Offset 级页内恢复 (Pixel-Offset Scroll Restore)
*状态: 暂不做 (Deferred — 风险高于收益)*

**背景:**
S1-NEXT 用 `position + offset` 恢复视口内像素位置；S1er 当前为楼级 `ScrollToFloor` + Plan B `_pageFloorMemory`，已覆盖跨会话续读与会话内翻页回看。

**暂不做的原因:**
- 图异步加载、字体、黑名单展开、投票卡等导致 item 高度变化，持久化 offset 易恢复到错误位置
- 懒列表 `scrollToIndex` 已有多轮估算；叠加 offset 微调易出现二次跳动
- `lastReadFloor` 为高水位语义，与「离开时视口 offset」纠缠，边界解释成本高
- 需动 Drift schema、备份格式、多条恢复路径，回归面大

**若未来重评:** 优先仅会话内 `_pageFloorMemory` 带 offset、**不落库**；跨会话仍用楼级对齐。
