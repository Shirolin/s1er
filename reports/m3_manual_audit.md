# M3 人工审计矩阵

> 审计日期：2026-07-11  
> 依据：[AGENTS.md](../AGENTS.md) M3 规范 + `dart run scripts/audit_m3.dart`

字段说明：色彩 / 排版 / 组件 / elevation / 形状 — `✓` 合规，`△` 有文档化例外，`—` 不适用

## Screens（10）

| 文件 | 色彩 | 排版 | 组件 | elevation | 形状 | 备注 |
|------|------|------|------|-----------|------|------|
| lib/screens/home_screen.dart | ✓ | ✓ | ✓ NavigationBar, Badge, FilledButton.tonal | ✓ | ✓ S1Shape | — |
| lib/screens/forum_list_screen.dart | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| lib/screens/thread_detail_screen.dart | ✓ | ✓ | ✓ TextButton, FAB | ✓ | ✓ | 已修复 filter bar TextStyle |
| lib/screens/compose_screen.dart | ✓ | ✓ | ✓ FilledButton | ✓ | ✓ | — |
| lib/screens/login_screen.dart | ✓ | ✓ | ✓ FilledButton | ✓ | ✓ | — |
| lib/screens/profile_screen.dart | ✓ | ✓ | ✓ FilledButton, ListTile | ✓ | ✓ S1Shape | 已改用 S1SnackBar |
| lib/screens/settings_screen.dart | ✓ | ✓ | ✓ | ✓ | ✓ | 组合 settings widgets |
| lib/screens/reading_history_screen.dart | ✓ | ✓ | ✓ FilledButton | ✓ | ✓ S1Shape | — |
| lib/screens/user_space_screen.dart | ✓ | ✓ | ✓ TabBar | ✓ | ✓ | 继承 tabBarTheme |
| lib/screens/image_viewer_screen.dart | ✓ | ✓ | ✓ IconButton | ✓ | ✓ S1Shape | scrim 用 scheme.scrim |

## Widgets（28）

| 文件 | 色彩 | 排版 | 组件 | elevation | 形状 | 备注 |
|------|------|------|------|-----------|------|------|
| lib/widgets/s1_error_view.dart | ✓ | ✓ | ✓ FilledButton | — | ✓ | — |
| lib/widgets/rate_log_card.dart | ✓ | ✓ | ✓ TextButton | ✓ | ✓ S1Shape | — |
| lib/widgets/s1_swipe_pagination.dart | ✓ | ✓ | ✓ | — | ✓ | — |
| lib/widgets/web_image_stub.dart | — | — | — | — | — | 平台桩，无 UI 主题 |
| lib/widgets/web_image_html.dart | — | — | — | — | — | 平台桩 |
| lib/widgets/web_avatar_stub.dart | — | — | — | — | — | 平台桩，委托 AvatarFallbackLetter |
| lib/widgets/web_avatar_html.dart | — | — | — | — | — | 平台桩，委托 AvatarFallbackLetter |
| lib/widgets/web_avatar.dart | ✓ | ✓ | ✓ | — | ✓ | AvatarFallbackLetter + FittedBox |
| lib/widgets/avatar_fallback.dart | ✓ | ✓ | ✓ | — | ✓ | 新增共享 fallback |
| lib/widgets/user_profile_sheet.dart | ✓ | ✓ | ✓ FilledButton, OutlinedButton, Chip | ✓ | ✓ | Chip 为交互标签 |
| lib/widgets/thread_card.dart | ✓ | ✓ | ✓ ActionChip | ✓ | ✓ S1Shape | — |
| lib/widgets/settings/theme_settings_section.dart | ✓ | ✓ | ✓ SegmentedButton, SwitchListTile | ✓ | ✓ S1Shape | 样式来自主题 |
| lib/widgets/settings/theme_color_picker.dart | ✓ | ✓ | ✓ | — | ✓ S1Shape | 已用 S1Contrast |
| lib/widgets/settings/settings_section_header.dart | ✓ | ✓ | ✓ | — | ✓ | — |
| lib/widgets/settings/settings_section.dart | ✓ | ✓ | ✓ | — | ✓ | — |
| lib/widgets/settings/font_size_section.dart | ✓ | ✓ | ✓ SegmentedButton | ✓ | ✓ S1Shape | 样式来自主题 |
| lib/widgets/settings/display_settings_section.dart | ✓ | ✓ | ✓ SwitchListTile, ListTile | ✓ | ✓ S1Shape | — |
| lib/widgets/s1_popup_menu.dart | ✓ | ✓ | ✓ | — | ✓ | 继承 menuTheme |
| lib/widgets/s1_fab_layout.dart | ✓ | — | ✓ FAB | — | ✓ | 继承 floatingActionButtonTheme |
| lib/widgets/quote_block.dart | ✓ | ✓ | ✓ Material | — | ✓ S1Shape | Colors.transparent 允许模式 |
| lib/widgets/post_item.dart | ✓ | ✓ | ✓ Badge | ✓ | ✓ S1Shape | 已从 Chip 改为 Badge |
| lib/widgets/post_action_menu.dart | ✓ | ✓ | ✓ | — | ✓ | 继承 menuTheme |
| lib/widgets/poll_card.dart | ✓ | ✓ | ✓ FilledButton | ✓ | ✓ S1Shape | API 色 + 对比度回退 |
| lib/widgets/pagination_bar.dart | ✓ | ✓ | ✓ IconButton | — | ✓ | — |
| lib/widgets/page_picker_sheet.dart | ✓ | ✓ | ✓ FilledButton, ListTile | — | ✓ S1Shape | — |
| lib/widgets/image_viewer.dart | ✓ | ✓ | ✓ | — | ✓ | — |
| lib/widgets/emoticon_widget.dart | ✓ | ✓ | ✓ | — | — | — |
| lib/widgets/bbcode_renderer.dart | ✓ | ✓ | ✓ | — | ✓ | 字号从 textTheme 桥接 |
| lib/widgets/app_bar_more_menu.dart | ✓ | ✓ | ✓ | — | ✓ | — |

## 主题层

| 文件 | 状态 | 备注 |
|------|------|------|
| lib/theme/app_theme.dart | ✓ | useMaterial3、fromSeed、全套子主题已补全 |
| lib/app.dart | ✓ | DynamicColorBuilder + AppTheme |

## 审计结论

- **38/38** UI 文件已逐项勾选
- **P0** 违规已修复（theme_color_picker、thread_detail TextStyle、post_item Badge）
- **P1** 已修复（SegmentedButton 主题化、S1SnackBar、S1Shape 统一）
- **P2** 已拆分为 AGENTS.md「M3 允许模式」；技术债已清零
- **边界项**（显式 elevation、S1Alpha、S1Typography、子主题、测试 AppTheme）已于 2026-07-11 全部修复
