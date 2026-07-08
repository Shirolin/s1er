# Material 3 UI 组件审计进度交接文档

本文件用于记录 **S1 Client** 项目中所有页面（Screens）与核心 UI 组件（Widgets）的 **Material Design 3 (M3)** 合规性审计进度，方便进度交接。

---

## 进度总览
- **总组件数**：15
- **已完成审计与重构**：15
- **待审计**：0
- **当前进度**：100%

---

## 一、已完成审计与重构组件

| 组件名称 | 源文件链接 | 审计通过日期 | 核心改动摘要 |
| :--- | :--- | :--- | :--- |
| **头部卡片 (`_HeaderCard`)** | [profile_screen.dart](file:///d:/Project/s1-app/lib/screens/profile_screen.dart#L102-L186) | 2026-07-08 | 1. 卡片底色取消 `0.4` 透明度以保障无障碍对比度。<br>2. 用户组 Container 优化为原生 Stadium 胶囊全圆角。<br>3. SizedBox 间距对齐 8dp 栅格。 |
| **主页与导航壳 (`HomeScreen`)** | [home_screen.dart](file:///d:/Project/s1-app/lib/screens/home_screen.dart) | 2026-07-08 | 1. 显式设置 AppBar 的 `elevation: 0` 和 `scrolledUnderElevation: 0`。<br>2. 卡片与列表项 Margin/Padding 严格 8dp 栅格化。<br>3. 分类头部背景重构为不透明的 `surfaceContainer`。<br>4. 子项图标移去 withValues 透明度混合。<br>5. 今日发帖气泡使用原生 `Badge` 组件（`error` 红色）。 |
| **版块列表页 (`ForumListScreen`)** | [forum_list_screen.dart](file:///d:/Project/s1-app/lib/screens/forum_list_screen.dart) | 2026-07-08 | 1. AppBar 显式设置 `elevation: 0` 和 `scrolledUnderElevation: 0`。<br>2. `_PaginationBar` padding 从 `12/6` 修正为 `16/8` 对齐 8dp 栅格。<br>3. `_NavButton` 从手写 InkWell 改用原生 `IconButton`，自动保障 48dp 触摸目标与禁用态颜色。<br>4. 页码跳转指示器从手写 Container 改用原生 `ActionChip`。<br>5. 移除不再使用的 `app_theme.dart` import。 |
| **帖子详情页 (`ThreadDetailScreen`)** | [thread_detail_screen.dart](file:///d:/Project/s1-app/lib/screens/thread_detail_screen.dart) | 2026-07-08 | 1. AppBar 显式设置 `elevation: 0` 和 `scrolledUnderElevation: 0`。<br>2. `_NavButton` 从手写 InkWell 改用原生 `IconButton`，自动保障 48dp 触摸目标与禁用态颜色。<br>3. 页码跳转指示器从手写 Container 改用原生 `ActionChip`。<br>4. Bottom sheet padding `20` 修正为 `16` 对齐 8dp 栅格。<br>5. FAB 间距 `12` 修正为 `16` 对齐 8dp 栅格。<br>6. 通用错误状态补充错误图标和 `scheme.error` 色。<br>7. 空状态文本 `'No posts'` 改为中文 `'暂无回复'`。<br>8. 移除不再使用的 `app_theme.dart` import。 |
| **发帖/回复编辑页 (`ComposeScreen`)** | [compose_screen.dart](file:///d:/Project/s1-app/lib/screens/compose_screen.dart) | 2026-07-08 | 1. AppBar 显式设置 `elevation: 0` 和 `scrolledUnderElevation: 0`。<br>2. 英文硬编码全部改为中文（`'Reply'`→`'回复'`、`'Submit'`→`'发送'`、`'Write your post...'`→`'输入回复内容...'`）。<br>3. 错误 SnackBar 补充 `Icons.error_outline` 图标和 `scheme.error` 背景色。 |
| **登录页 (`LoginScreen`)** | [login_screen.dart](file:///d:/Project/s1-app/lib/screens/login_screen.dart) | 2026-07-08 | 1. AppBar 显式设置 `elevation: 0` 和 `scrolledUnderElevation: 0`。<br>2. `FilledButton` 移除 `S1Shape.small` shape 覆写，使用 M3 默认全圆角胶囊形按钮。 |
| **大图查看页 (`ImageViewerScreen`)** | [image_viewer_screen.dart](file:///d:/Project/s1-app/lib/screens/image_viewer_screen.dart) | 2026-07-08 | 1. AppBar `iconTheme` 改用 M3 推荐的 `foregroundColor` 属性。 |
| **帖子卡片 (`ThreadCard`)** | [thread_card.dart](file:///d:/Project/s1-app/lib/widgets/thread_card.dart) | 2026-07-08 | 1. Card margin `vertical: 3` 修正为 `4` 对齐 8dp 栅格。<br>2. Card padding `vertical: 10` 修正为 `8` 对齐 8dp 栅格。<br>3. 移除全部 `S1Alpha` 透明度混合（9 处），改用 M3 正确语义色。<br>4. `_CategoryTag` 从手写 Container 改用原生 `Chip`。<br>5. 页码徽章从手写 Container 改用原生 `ActionChip`。<br>6. Bottom sheet header padding `20` 修正为 `24` 对齐 8dp 栅格。<br>7. Bottom sheet 列表项 padding `vertical: 10` 修正为 `8`。 |
| **回复楼层 item (`PostItem`)** | [post_item.dart](file:///d:/Project/s1-app/lib/widgets/post_item.dart) | 2026-07-08 | 1. 楼层徽章从手写 Container + `S1Alpha.half` 改用原生 `Chip`，移除 alpha 混合。<br>2. 用户信息弹窗 padding `20` 修正为 `16` 对齐 8dp 栅格。<br>3. 帖子列表头像 `radius: 16`（32dp）增大为 `20`（40dp），符合 M3 最小推荐尺寸。 |
| **引用块 (`QuoteBlock`)** | [quote_block.dart](file:///d:/Project/s1-app/lib/widgets/quote_block.dart) | 2026-07-08 | 1. 移除全部 `S1Alpha` 透明度混合（4 处），改用 M3 tonal surface 层级（`surfaceContainer`/`surfaceContainerHigh`/`surfaceContainerHighest`）+ `outlineVariant`/`primary`/`tertiary` 边框色。<br>2. margin `vertical: 6` 修正为 `8` 对齐 8dp 栅格。<br>3. padding `10` 修正为 `12`、`6` 修正为 `8` 对齐 8dp 栅格。<br>4. `BorderRadius.only(topRight: 8)` 改用 `S1Shape.small`。 |
| **富文本 BBCode 渲染器 (`BbcodeRenderer`)** | [bbcode_renderer.dart](file:///d:/Project/s1-app/lib/widgets/bbcode_renderer.dart) | 2026-07-08 | 1. 移除全部 `S1Alpha` 透明度混合（3 处）：`pre` 背景改用 `surfaceContainerHighest`、`hide-content` 背景改用 `outlineVariant`、图片边框改用 `outlineVariant`。<br>2. `li` margin `bottom: 6` 修正为 `8` 对齐 8dp 栅格。<br>3. `fontSize` 硬编码标注为 flutter_html beta 已知限制，暂保留。 |
| **表情包组件 (`EmoticonWidget`)** | [emoticon_widget.dart](file:///d:/Project/s1-app/lib/widgets/emoticon_widget.dart) | 2026-07-08 | 无需修改，已符合 M3 规范。 |
| **图片查看器 (`ImageViewer`)** | [image_viewer.dart](file:///d:/Project/s1-app/lib/widgets/image_viewer.dart) | 2026-07-08 | 1. 错误背景 `S1Alpha.medium` 透明度混合移除，改用 `surfaceContainerHighest` 固态色。<br>2. 加载指示器高度 `100` 修正为 `96` 对齐 8dp 栅格。 |
| **顶部 App Bar 溢出菜单 (`AppBarMoreMenu`)** | [app_bar_more_menu.dart](file:///d:/Project/s1-app/lib/widgets/app_bar_more_menu.dart) | 2026-07-08 | 无需修改，已符合 M3 规范。 |
| **跨平台头像 (`WebAvatar`)** | [web_avatar.dart](file:///d:/Project/s1-app/lib/widgets/web_avatar.dart) | 2026-07-08 | 无需修改，已符合 M3 规范。 |

---

## 二、待审计组件清单

以下组件仍需按照 M3 规范（[material-3 SKILL](file:///d:/Project/s1-app/.agents/skills/material-3/SKILL.md)）逐个进行详细审计与修正：

### 1. 页面级组件 (Screens)

| 页面名称 | 源文件链接 | 主要关注点预估 |
| :--- | :--- | :--- |

### 2. 通用功能组件 (Widgets)

| 组件名称 | 源文件链接 | 主要关注点预估 |
| :--- | :--- | :--- |

---

## 进度更新流程
每次完成新的组件审计与重构后，请编辑更新此文档，将对应组件移至**“已完成”**中，并标注更新日期和核心重构内容。
