# S1er TODO List

## 待实现功能 (Features to Implement)

### 1. 多楼层分享功能 (Multi-Floor Share)
*状态: 规划中 (Planned)*

**功能描述:**
支持在帖子详情页选择多个楼层，生成长截图进行分享。

**实现计划 (MVP 阶段):**
- **UI/UX 改动**: 在 `ThreadDetailScreen` 引入“多选模式”。点击楼层切换选中状态，底部显示已选楼层数量及“生成分享图”按钮。
- **性能与 OOM 控制**: 为了避免低端机生成过长图片导致内存溢出 (OOM)，**限制最多同时选择 5 个楼层**。
- **渲染方案**: 沿用当前的 `RepaintBoundary` 技术进行渲染。
- **数据结构**: 重构 `ShareCard` 和 `PostShareService`，使其支持接收 `List<Post>`，并处理楼层间的分割线与上下留白。

**长期优化 (视用户反馈):**
- 如果用户需要分享超过 5 个楼层，探索使用 `image` 库在隔离线程 (Isolate) 中进行分块渲染和拼接的技术方案，绕过 GPU 的最大纹理限制。

### 2. 富文本编辑功能完善 (Rich Text Editor Enhancements)
*状态: 规划中 (Planned)*

**功能描述:**
完善发帖、回帖、编辑帖子时的富文本相关功能，提供更好的排版和输入体验。

**实现计划:**
- **基础排版支持**: 支持加粗、斜体、下划线、删除线、字体颜色和大小调整等常用 BBCode 标签。
- **媒体与超链接**: 完善插入图片（如图床上传集成）、插入超链接的交互体验。
- **引用与代码块**: 提供快捷插入引用块、代码块的功能，并处理好对应的 BBCode 转换。
- **S1 特色功能**: 完善麻将脸（表情）面板的快速唤起与插入，支持隐藏内容（黑幕/刮刮乐）、剧透警告等特有标签。
- **预览功能**: 提供发帖/回复前的实时或全屏预览功能，确保排版效果与最终展示一致。

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
