# 游客访问改造计划

## 背景

历史实测中，S1 论坛 API（`forumindex` / `forumdisplay` / `viewthread`）曾支持无登录的游客读取。但 `home_screen.dart` 曾在未登录时对 **所有 Tab**（论坛/搜索/消息/我的）统一展示 `_LoginPrompt` 锁屏，完全阻断了游客浏览入口。

当前状态（2026-07-11 实测）：未登录请求 `forumindex`、`forumdisplay` 以及桌面论坛页都会返回登录要求或登录页。也就是说 App 的游客入口仍应存在，但实际论坛内容是否可读取取决于 S1 服务器当前是否开放游客访问。

## 改造目标

App 未登录状态可直接进入论坛入口；如果 S1 当前开放游客读取，则可浏览版块列表、帖子列表、帖子详情（只读）。如果 S1 返回 `to_login`，展示登录提示。写操作（回复/投票/发帖）仍需登录，触发时引导登录。

## 改动范围

### 1. `lib/screens/home_screen.dart` — 移除全屏登录门控

**现状**（L57-58）：
```dart
body: !isLoggedIn && _currentTab < 3
    ? _LoginPrompt()
    : ...
```
游客在 Tab 0/1/2 时一律看到锁屏。

**改为**：
- Tab 0（论坛）：**始终展示 `_ForumTab`**，移除登录前置条件。
- Tab 1（搜索）：保持原样（占位 Text，无需登录）。
- Tab 2（消息）：游客时展示"登录后查看消息"提示（保留 `_LoginPrompt` 或简化版），已登录则正常展示。
- Tab 3（我的）：**保持现状**，`ProfileBody` 内部已处理未登录状态。

```dart
body: _currentTab == 0
    ? const _ForumTab()
    : _currentTab == 1
        ? const Center(child: Text('Search'))
        : _currentTab == 2
            ? isLoggedIn
                ? const Center(child: Text('Messages'))
                : _LoginPrompt()
            : const ProfileBody(),
```

### 2. `lib/screens/home_screen.dart` — 未登录时隐藏"搜索"和"消息"Tab

搜索和消息功能对游客无意义，直接隐藏这两个 Tab 目的地，避免游客看到无用入口。

```dart
bottomNavigationBar: NavigationBar(
  selectedIndex: _currentTab,
  onDestinationSelected: (index) {
    // 游客模式下 Tab 索引映射需要处理
    setState(() => _currentTab = index);
  },
  destinations: isLoggedIn
      ? const [
          NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.message), label: '消息'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ]
      : const [
          NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
),
```

> **注意**：游客模式下只有 2 个 Tab（论坛=0，我的=1），需用 `_currentTab` 映射逻辑处理索引。实现时引入一个 `_effectiveTabIndex` getter 或直接在游客模式下将 Tab 1 映射到 ProfileBody。

### 3. `lib/screens/home_screen.dart` — AppBar 登录按钮保留

L51-54 的 `FilledButton.tonal` 登录按钮在未登录时展示，**保持不变**。这是游客发现登录入口的主要途径。

### 4. `lib/screens/thread_detail_screen.dart` — 无需改动

- 回复 FAB 已通过 `isLoggedIn` 条件隐藏（L281-290）✅
- 阅读历史已用 `'guest'` uid 隔离 ✅
- API 层的 `LoginRequiredException` 由 `S1ErrorView` 处理 ✅

### 5. `lib/services/api_service.dart` — 无需改动

`checkAuthError` 检测 API 返回的 `to_login` 错误并抛出 `LoginRequiredException`。这个机制对游客是合理的：如果 S1 当前要求登录，会展示 `S1ErrorView` 的"请先登录"界面并提供登录按钮。

### 6. `lib/widgets/s1_error_view.dart` — 无需改动

已正确处理 `LoginRequiredException`，展示锁图标 + "请先登录" + 当前 S1 需要登录查看内容的说明 + "去登录"按钮。

### 7. `lib/providers/reading_history_provider.dart` — 无需改动

L17-18 已将无 uid 的情况归入 `'guest'`，阅读历史对游客正常工作。

## 不改动的部分

| 文件 | 原因 |
|:---|:---|
| `app.dart`（路由） | 路由无登录守卫，游客可直接导航到 `/forum/:fid` 和 `/thread/:tid` |
| `auth_provider.dart` | 游客状态 = `AuthState()` 默认值（`isLoggedIn: false`），无需修改 |
| `forum_list_provider.dart` | 不做本地登录门控；`getForumList()` 在上游允许时可游客读取，上游返回 `to_login` 时正常降级到登录提示 |
| `thread_list_provider.dart` | 不做本地登录门控；`getThreadList()` 在上游允许时可游客读取，上游返回 `to_login` 时正常降级到登录提示 |
| `compose_screen.dart` | 发帖/回复需登录，由路由层 FAB 控制入口 |
| `profile_screen.dart` | `ProfileBody` 内部已处理未登录状态 |

## 验收标准

1. **游客入口可用**：冷启动未登录 → 可进入论坛 Tab；如果 S1 当前开放游客读取，则直接看到论坛版块列表。
2. **写操作引导**：游客在帖子详情页看不到回复 FAB；若 API 返回 `to_login`，展示 `S1ErrorView` 并提供"去登录"按钮。
3. **登录后完整功能**：登录后自动刷新为完整 4-Tab 布局，回复 FAB 出现。
4. **Tab 切换正常**：游客 2-Tab 模式下切换论坛↔我的无异常。
5. **`flutter analyze` 无新增 error/warning。**
