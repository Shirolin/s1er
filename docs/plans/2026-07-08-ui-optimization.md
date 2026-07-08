# UI 优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优化登录界面交互、底部导航栏中文化、板块列表显示今日新帖数

**Architecture:** 三个独立优化任务，涉及 login_screen.dart、home_screen.dart、forum_category.dart、api_service.dart 等文件

**Tech Stack:** Flutter, Riverpod, GoRouter

## Global Constraints

- Material Design 3 规范
- 使用 `Theme.of(context).colorScheme` 取色
- 使用 `textTheme` 标准层级
- 文件命名 snake_case，类命名 PascalCase

---

## Task 1: 登录界面优化

**Files:**
- Modify: `lib/screens/login_screen.dart`

**Interfaces:**
- 无外部依赖变更

- [ ] **Step 1: 添加密码显示/隐藏状态变量**

```dart
bool _obscurePassword = true;
```

- [ ] **Step 2: 修改用户名字段，添加 onSubmitted 跳转密码字段**

需要添加 FocusNode 和处理回车事件：

```dart
final _usernameFocus = FocusNode();
final _passwordFocus = FocusNode();

// 在 dispose 中释放
@override
void dispose() {
  _usernameController.dispose();
  _passwordController.dispose();
  _usernameFocus.dispose();
  _passwordFocus.dispose();
  super.dispose();
}
```

修改用户名 TextField：
```dart
TextField(
  controller: _usernameController,
  focusNode: _usernameFocus,
  decoration: const InputDecoration(
    labelText: '用户名',
    prefixIcon: Icon(Icons.person),
  ),
  keyboardType: TextInputType.text,
  textInputAction: TextInputAction.next,
  onSubmitted: (_) => _passwordFocus.requestFocus(),
),
```

- [ ] **Step 3: 修改密码字段，添加眼睛图标和焦点控制**

```dart
TextField(
  controller: _passwordController,
  focusNode: _passwordFocus,
  decoration: InputDecoration(
    labelText: '密码',
    prefixIcon: const Icon(Icons.lock),
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePassword ? Icons.visibility_off : Icons.visibility,
      ),
      onPressed: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
    ),
  ),
  obscureText: _obscurePassword,
  onSubmitted: (_) => _handleLogin(),
),
```

- [ ] **Step 4: 测试验证**

运行应用，验证：
- 用户名输入框回车后焦点跳转到密码框
- 密码框回车后触发登录
- 点击眼睛图标切换密码显示/隐藏

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login_screen.dart
git commit -m "feat(login): 支持回车登录和密码显示切换"
```

---

## Task 2: 底部导航栏中文化

**Files:**
- Modify: `lib/screens/home_screen.dart:73-78`

**Interfaces:**
- 无外部依赖变更

- [ ] **Step 1: 修改 NavigationDestination labels**

将：
```dart
destinations: const [
  NavigationDestination(icon: Icon(Icons.forum), label: 'Forum'),
  NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
  NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
  NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
],
```

改为：
```dart
destinations: const [
  NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
  NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
  NavigationDestination(icon: Icon(Icons.message), label: '消息'),
  NavigationDestination(icon: Icon(Icons.person), label: '我的'),
],
```

- [ ] **Step 2: 测试验证**

运行应用，验证底部导航栏显示中文标签

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(home): 底部导航栏标签改为中文"
```

---

## Task 3: 板块列表显示今日新帖数

**Files:**
- Modify: `lib/models/forum_category.dart`
- Modify: `lib/services/api_service.dart`
- Modify: `lib/screens/home_screen.dart`

**Interfaces:**
- ForumCategory 新增 `todayPosts` 字段
- parseForumList 解析逻辑需处理 todayposts 字段

- [ ] **Step 1: 修改 ForumCategory 模型，添加 todayPosts 字段**

```dart
class ForumCategory {
  ForumCategory({
    required this.fid,
    required this.name,
    required this.description,
    required this.threads,
    required this.posts,
    this.todayPosts = 0,
    this.icon,
    this.subforums = const [],
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    final subforumList = json['sublist'] as List? ?? [];
    return ForumCategory(
      fid: json['fid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      threads: int.tryParse(json['threads']?.toString() ?? '') ?? 0,
      posts: int.tryParse(json['posts']?.toString() ?? '') ?? 0,
      todayPosts: int.tryParse(json['todayposts']?.toString() ?? '') ?? 0,
      icon: json['icon']?.toString(),
      subforums: subforumList
          .map((f) => ForumCategory.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
  final String fid;
  final String name;
  final String description;
  final int threads;
  final int posts;
  final int todayPosts;
  final String? icon;
  final List<ForumCategory> subforums;
}
```

- [ ] **Step 2: 修改 parseForumList 累加今日帖子数**

在 `api_service.dart` 的 `parseForumList` 方法中，累加子版块的 todayPosts：

```dart
int totalThreads = 0;
int totalPosts = 0;
int totalTodayPosts = 0;
for (final sub in subforums) {
  totalThreads += sub.threads;
  totalPosts += sub.posts;
  totalTodayPosts += sub.todayPosts;
}

categories.add(ForumCategory(
  fid: catFid,
  name: catName,
  description: '',
  threads: totalThreads,
  posts: totalPosts,
  todayPosts: totalTodayPosts,
  subforums: subforums,
),);
```

- [ ] **Step 3: 修改 _ForumTile 显示今日新帖数**

在 `home_screen.dart` 的 `_ForumTile` 中，将右侧的帖子数改为显示今日新帖：

```dart
// 帖子数改为今日新帖
if (forum.todayPosts > 0)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '${forum.todayPosts}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: scheme.onPrimaryContainer,
      ),
    ),
  ),
```

- [ ] **Step 4: 测试验证**

运行应用，验证：
- 板块列表右侧显示今日新帖数
- 今日无新帖时不显示数字徽章
- 分类头部的统计数字正确累加

- [ ] **Step 5: Commit**

```bash
git add lib/models/forum_category.dart lib/services/api_service.dart lib/screens/home_screen.dart
git commit -m "feat(home): 板块列表显示今日新帖数量"
```

---

## 验收标准

- [ ] 登录界面：用户名回车跳转密码框，密码框回车触发登录，眼睛图标切换密码可见性
- [ ] 底部导航栏：显示中文标签（论坛、搜索、消息、我的）
- [ ] 板块列表：每个板块显示今日新帖数量徽章
- [ ] `flutter analyze` 无 error/warning
