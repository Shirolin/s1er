# 0010. 桌面端鼠标指针策略：显式手型 + 审计门禁

- 状态：已接受
- 日期：2026-11-09
- 相关：`lib/theme/s1_mouse_cursors.dart`、`lib/theme/app_theme.dart`、`scripts/audit_cursors.dart`、`lib/screens/home_screen.dart`、`lib/widgets/s1_desktop_scaffold.dart`

## 背景

Flutter 3.44 的 Material 默认指针是 `WidgetStateMouseCursor.adaptiveClickable`：
web 解析为手型，桌面（Windows/macOS/Linux）解析为箭头。该默认来自
[flutter#171796](https://github.com/flutter/flutter/pull/171796)，动机是 Android
带鼠标时的箭头建议；随后被 [flutter#182466](https://github.com/flutter/flutter/issues/182466)
指为「把 Android 规则错误地全局化、桌面失去手型」的 P1 回归，至今未回滚。

S1er 是论坛内容型桌面客户端，2026-07 已选择「桌面也用手型」（commit `96cfc29`）。
但当时只覆盖了 ThemeData 有 `mouseCursor` 槽的组件（按钮、ListTile、Checkbox 等）：

- 裸 `InkWell`/`InkResponse` 仍走 `adaptiveClickable` → 桌面箭头；
- `ChipThemeData`、`NavigationBarThemeData`、`NavigationRailThemeData` 在 3.44
  **没有** `mouseCursor` 字段，主题补不到。

结果是指针行为半手型半箭头，且随 Flutter 升级漂移。

## 决策

**所有可交互表面统一为手型；在源码显式声明，不依赖框架默认值。**

1. 可点的 `InkWell` 统一改用 `S1InkWell`（`lib/widgets/s1_ink_well.dart`），
   由其默认注入 `S1MouseCursors.clickable`；不在每个调用点重复写参数。
2. `InkResponse` 不在本项目直接使用；若将来需要，按同样方式封装。
3. 有主题槽的组件继续在 `app_theme.dart` 里配置。
4. `NavigationBar` / `NavigationRail` 用 `MouseRegion(cursor: S1MouseCursors.clickable)`
   包裹（框架无主题槽）。
5. Chip 系列（`ActionChip`/`FilterChip`/`ChoiceChip`/`InputChip`）无统一包装，
   在调用点显式传 `mouseCursor: S1MouseCursors.clickable`。
6. 语义指针保持原义：输入框 `text`、分栏 `resizeColumn`、禁用回 `basic`
   （`WidgetStateMouseCursor.clickable` 已自动处理禁用态）。
7. **纯展示**的 Chip/卡片不传 `mouseCursor`，保持箭头。
8. `scripts/audit_cursors.dart --fail-on-error` 扫描 `lib/`：可交互但既不是
   `S1InkWell` 也没有显式 `mouseCursor:` 的构造调用即报错。

## 结果

- 显式 `mouseCursor` 属于本项目源码，Flutter 升级不会改掉它，不会再被默认值覆盖。
- 审计脚本阻止新代码漏写；需接入 pre-commit / CI 才能形成硬门禁（待办）。
- 代价：`S1InkWell` 多一层参数转发；Chip 仍要逐点显式传 cursor；由审计兜底。

## 备选方案

- **跟随原生桌面（全箭头，只给链接手型）**：与 Flutter 当前默认一致、零维护，
  但推翻了 2026-07 的产品选择，也与 #182466 的用户预期相反。已否决。
- **只依赖 Flutter 默认**：默认值跨版本变化（正是本次问题），不可控。已否决。
- **等 [flutter#182652](https://github.com/flutter/flutter/pull/182652) 提供
  InkWell 主题级 cursor 后统一配置**：上游未稳定，不能作为当前方案；待落地后可简化。
