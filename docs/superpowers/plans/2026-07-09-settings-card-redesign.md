# 设置卡片重设计实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将个人资料页面中的设置区域从单一卡片拆分为两个独立的卡片，增强视觉层次和交互体验。

**Architecture:** 将 `_SettingsCard` 组件拆分为 `_ThemeSettingsCard` 和 `_DisplaySettingsCard` 两个独立组件，分别处理主题设置和显示设置。保持现有的数据流和业务逻辑不变，仅改变UI展示。

**Tech Stack:** Flutter, Material Design 3, flutter_riverpod

## Global Constraints

- Flutter SDK >=3.4
- 使用 Material Design 3 规范
- 遵循项目命名约定：snake_case 文件名，camelCase 函数/变量名，PascalCase 类名
- 从 `Theme.of(context).colorScheme` 获取语义色
- 从 `textTheme` 获取排版样式
- 禁止硬编码颜色值和字体大小

---

## 文件结构

### 修改文件
- `lib/screens/profile_screen.dart`：
  - 删除 `_SettingsCard` 类
  - 添加 `_ThemeSettingsCard` 类
  - 添加 `_DisplaySettingsCard` 类
  - 添加 `_getColorLabel` 辅助函数
  - 更新 `ProfileBody` 中的布局

### 测试文件
- `test/screens/profile_screen_test.dart`：更新测试以覆盖新的组件

---

## 任务分解

### Task 1: 准备测试环境

**Files:**
- Create: `test/screens/profile_screen_test.dart`
- Modify: `lib/screens/profile_screen.dart` (添加必要的导出)

**Interfaces:**
- Consumes: 无
- Produces: 测试文件结构，用于后续任务的测试

- [ ] **Step 1: 检查现有测试结构**

```bash
ls test/
```

- [ ] **Step 2: 创建测试文件**

```dart
// test/screens/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/screens/profile_screen.dart';
import 'package:s1_app/providers/settings_provider.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('should display settings cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // 验证设置卡片存在
      expect(find.text('主题设置'), findsOneWidget);
      expect(find.text('显示设置'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: 运行测试验证失败**

```bash
flutter test test/screens/profile_screen_test.dart
```

预期：失败，因为 `ProfileScreen` 还没有导出，且新组件尚未创建。

- [ ] **Step 4: 提交**

```bash
git add test/screens/profile_screen_test.dart
git commit -m "test: add profile screen test scaffold"
```

---

### Task 2: 拆分 _SettingsCard 为 _ThemeSettingsCard

**Files:**
- Modify: `lib/screens/profile_screen.dart:406-590`

**Interfaces:**
- Consumes: `themeMode`, `themeColor`, `onThemeModeChanged`, `onThemeColorChanged` 参数
- Produces: `_ThemeSettingsCard` 类

- [ ] **Step 1: 创建 _ThemeSettingsCard 类**

在 `lib/screens/profile_screen.dart` 中，在 `_SettingsCard` 类之前添加：

```dart
class _ThemeSettingsCard extends StatelessWidget {
  const _ThemeSettingsCard({
    required this.themeMode,
    required this.themeColor,
    required this.onThemeModeChanged,
    required this.onThemeColorChanged,
  });
  
  final String themeMode;
  final String themeColor;
  final ValueChanged<String> onThemeModeChanged;
  final ValueChanged<String> onThemeColorChanged;
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '主题设置',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '主题外观',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'system',
                  label: Text('跟随系统'),
                  icon: Icon(Icons.brightness_auto, size: 18),
                ),
                ButtonSegment(
                  value: 'light',
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode, size: 18),
                ),
                ButtonSegment(
                  value: 'dark',
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode, size: 18),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (v) => onThemeModeChanged(v.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return BorderSide.none;
                  }
                  return BorderSide(
                    color: colorScheme.outlineVariant,
                  );
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.secondaryContainer;
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.onSecondaryContainer;
                  }
                  return colorScheme.onSurfaceVariant;
                }),
                shape: WidgetStateProperty.all(
                  const RoundedRectangleBorder(
                    borderRadius: S1Shape.medium,
                  ),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, indent: 0, endIndent: 0),
            const SizedBox(height: 20),
            Text(
              '主题配色',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: AppTheme.themeSeeds.entries.map((entry) {
                final key = entry.key;
                final color = entry.value;
                final isSelected = themeColor == key;
                return GestureDetector(
                  onTap: () => onThemeColorChanged(key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: colorScheme.primary,
                                  width: 3,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black87
                                    : Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getColorLabel(key),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 添加 _getColorLabel 辅助函数**

在 `_ThemeSettingsCard` 类之前添加：

```dart
String _getColorLabel(String key) {
  const labels = {
    'blue': '蓝',
    'purple': '紫',
    'sage': '绿',
    'indigo': '黛',
    'orange': '橙',
  };
  return labels[key] ?? key;
}
```

- [ ] **Step 3: 运行测试验证**

```bash
flutter test test/screens/profile_screen_test.dart
```

预期：测试仍然失败，因为 `ProfileScreen` 还没有导出。

- [ ] **Step 4: 提交**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add _ThemeSettingsCard component"
```

---

### Task 3: 拆分 _SettingsCard 为 _DisplaySettingsCard

**Files:**
- Modify: `lib/screens/profile_screen.dart`

**Interfaces:**
- Consumes: `showImages`, `onShowImagesChanged` 参数
- Produces: `_DisplaySettingsCard` 类

- [ ] **Step 1: 创建 _DisplaySettingsCard 类**

在 `_ThemeSettingsCard` 类之后添加：

```dart
class _DisplaySettingsCard extends StatelessWidget {
  const _DisplaySettingsCard({
    required this.showImages,
    required this.onShowImagesChanged,
  });
  
  final bool showImages;
  final ValueChanged<bool> onShowImagesChanged;
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: S1Shape.cardShape,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '显示设置',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('显示图片'),
              secondary: const Icon(Icons.image_outlined),
              value: showImages,
              onChanged: onShowImagesChanged,
              shape: const RoundedRectangleBorder(
                borderRadius: S1Shape.medium,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1, indent: 0, endIndent: 0),
            const _VersionTile(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行测试验证**

```bash
flutter test test/screens/profile_screen_test.dart
```

预期：测试仍然失败，因为 `ProfileScreen` 还没有导出。

- [ ] **Step 3: 提交**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add _DisplaySettingsCard component"
```

---

### Task 4: 更新 ProfileBody 布局

**Files:**
- Modify: `lib/screens/profile_screen.dart:55-103`

**Interfaces:**
- Consumes: `_ThemeSettingsCard`, `_DisplaySettingsCard` 组件
- Produces: 更新后的 `ProfileBody` 布局

- [ ] **Step 1: 更新 ProfileBody 中的布局**

找到 `ProfileBody` 的 `build` 方法，将 `_SettingsCard` 替换为新的组件：

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final authState = ref.watch(authStateProvider);
  final settings = ref.watch(settingsProvider);
  final user = authState.user;
  final colorScheme = Theme.of(context).colorScheme;

  final avatarUrl = User.resolveAvatarUrl(user?.avatar, size: 'middle');
  final letter = (authState.username?.isNotEmpty == true)
      ? authState.username![0].toUpperCase()
      : '?';

  return ListView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    children: [
      _HeaderCard(
        avatarUrl: avatarUrl,
        letter: letter,
        username: authState.isLoggedIn
            ? (user?.username ?? authState.username ?? '')
            : null,
        groupTitle: user?.groupTitle,
        isLoggedIn: authState.isLoggedIn,
        onLogin: () => context.push('/login'),
      ),
      if (authState.isLoggedIn && user != null && user.uid.isNotEmpty) ...[
        const SizedBox(height: 16),
        _StatsCard(user: user),
        const SizedBox(height: 16),
        _S1StatsCard(user: user),
        const SizedBox(height: 16),
        _InfoCard(user: user),
      ],
      const SizedBox(height: 20),
      _ThemeSettingsCard(
        themeMode: settings.themeMode,
        themeColor: settings.themeColor,
        onThemeModeChanged: (v) =>
            ref.read(settingsProvider.notifier).setThemeMode(v),
        onThemeColorChanged: (v) =>
            ref.read(settingsProvider.notifier).setThemeColor(v),
      ),
      const SizedBox(height: 16),
      _DisplaySettingsCard(
        showImages: settings.showImages,
        onShowImagesChanged: (v) =>
            ref.read(settingsProvider.notifier).setShowImages(v),
      ),
      const SizedBox(height: 16),
      if (authState.isLoggedIn)
        _ActionTile(
          icon: Icons.logout,
          label: '退出登录',
          color: colorScheme.error,
          onTap: () {
            ref.read(authStateProvider.notifier).logout();
            context.go('/');
          },
        ),
      const SizedBox(height: 24),
    ],
  );
}
```

- [ ] **Step 2: 删除旧的 _SettingsCard 类**

删除 `lib/screens/profile_screen.dart` 中的 `_SettingsCard` 类（第406-590行）。

- [ ] **Step 3: 运行测试验证**

```bash
flutter test test/screens/profile_screen_test.dart
```

预期：测试通过。

- [ ] **Step 4: 提交**

```bash
git add lib/screens/profile_screen.dart
git commit -m "refactor: update ProfileBody layout with new settings cards"
```

---

### Task 5: 导出 ProfileScreen

**Files:**
- Modify: `lib/screens/profile_screen.dart`

**Interfaces:**
- Consumes: 无
- Produces: 导出的 `ProfileScreen` 类

- [ ] **Step 1: 检查是否需要导出**

查看 `lib/screens/profile_screen.dart` 文件顶部，确认 `ProfileScreen` 类是否已导出。如果没有，在文件顶部添加：

```dart
export 'profile_screen.dart';
```

- [ ] **Step 2: 运行测试验证**

```bash
flutter test test/screens/profile_screen_test.dart
```

预期：测试通过。

- [ ] **Step 3: 提交**

```bash
git add lib/screens/profile_screen.dart
git commit -m "fix: export ProfileScreen for testing"
```

---

### Task 6: 完善测试覆盖

**Files:**
- Modify: `test/screens/profile_screen_test.dart`

**Interfaces:**
- Consumes: `_ThemeSettingsCard`, `_DisplaySettingsCard` 组件
- Produces: 完整的测试覆盖

- [ ] **Step 1: 更新测试用例**

```dart
// test/screens/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/screens/profile_screen.dart';
import 'package:s1_app/providers/settings_provider.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('should display theme settings card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // 验证主题设置卡片存在
      expect(find.text('主题设置'), findsOneWidget);
      expect(find.text('主题外观'), findsOneWidget);
      expect(find.text('主题配色'), findsOneWidget);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);
    });

    testWidgets('should display display settings card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // 验证显示设置卡片存在
      expect(find.text('显示设置'), findsOneWidget);
      expect(find.text('显示图片'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
    });

    testWidgets('should display color labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // 验证颜色标签存在
      expect(find.text('蓝'), findsOneWidget);
      expect(find.text('紫'), findsOneWidget);
      expect(find.text('绿'), findsOneWidget);
      expect(find.text('黛'), findsOneWidget);
      expect(find.text('橙'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证**

```bash
flutter test test/screens/profile_screen_test.dart
```

预期：所有测试通过。

- [ ] **Step 3: 提交**

```bash
git add test/screens/profile_screen_test.dart
git commit -m "test: add comprehensive tests for settings cards"
```

---

### Task 7: 代码质量检查

**Files:**
- Modify: 无（仅检查）

**Interfaces:**
- Consumes: 无
- Produces: 无

- [ ] **Step 1: 运行 Flutter 分析**

```bash
flutter analyze
```

预期：无错误或警告。

- [ ] **Step 2: 运行所有测试**

```bash
flutter test
```

预期：所有测试通过。

- [ ] **Step 3: 提交（如果有修复）**

```bash
git add .
git commit -m "fix: resolve lint issues"
```

---

### Task 8: 最终验证

**Files:**
- Modify: 无（仅验证）

**Interfaces:**
- Consumes: 无
- Produces: 无

- [ ] **Step 1: 在 Web 平台运行**

```bash
flutter run -d chrome
```

验证：
- 设置卡片正确显示
- 颜色选择器有标签
- 开关切换正常
- 版本信息点击5次能打开TalkerScreen

- [ ] **Step 2: 在 Android 平台运行**

```bash
flutter run -d android
```

验证：
- 设置卡片正确显示
- 颜色选择器有标签
- 开关切换正常
- 版本信息点击5次能打开TalkerScreen

- [ ] **Step 3: 最终提交**

```bash
git add .
git commit -m "feat: complete settings card redesign"
```

---

## 执行选项

计划完成并保存到 `docs/superpowers/plans/2026-07-09-settings-card-redesign.md`。两种执行方式：

**1. Subagent-Driven（推荐）** - 我为每个任务分发一个新的子代理，在任务之间进行审查，快速迭代

**2. Inline Execution** - 在当前会话中使用 executing-plans 执行任务，批量执行并设置检查点

你选择哪种方式？
