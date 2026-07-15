# 设置卡片重设计 - 设计文档

## 概述

美化个人资料页面中的设置区域，将单一设置卡片拆分为两个独立的卡片，增强视觉层次和交互体验。

## 设计目标

1. **视觉层次**：将设置项分成两个逻辑清晰的卡片
2. **交互体验**：改进颜色选择器，增加标签和动画
3. **代码结构**：将 `_SettingsCard` 拆分为两个独立的组件

## 设计方案

### 卡片分组

#### 1. 主题设置卡片
- **内容**：主题外观选择 + 主题配色选择
- **标题**：使用 `LabelLarge` 样式，颜色为 `colorScheme.primary`
- **布局**：垂直排列，主题外观在上，主题配色在下

#### 2. 显示设置卡片
- **内容**：显示图片开关 + 版本信息
- **标题**：使用 `LabelLarge` 样式，颜色为 `colorScheme.primary`
- **布局**：使用列表项布局

### 主题设置卡片设计

#### 主题外观部分
- **标题**：使用 `bodyMedium` 样式，颜色为 `colorScheme.onSurfaceVariant`
- **组件**：保持现有的 `SegmentedButton` 组件
- **间距**：标题与按钮之间使用 `12px` 间距

#### 主题配色部分
- **标题**：使用 `bodyMedium` 样式，颜色为 `colorScheme.onSurfaceVariant`
- **颜色圆点**：使用 `48px` 尺寸
- **颜色标签**：每个颜色下方添加小标签（蓝、紫、绿、黛、橙）
- **选中效果**：使用 `AnimatedContainer` 添加平滑动画
- **间距**：标题与颜色圆点之间使用 `12px` 间距

### 显示设置卡片设计

#### 显示图片开关
- **组件**：使用 `SwitchListTile` 组件
- **图标**：使用 `Icons.image_outlined`
- **样式**：保持现有的 M3 样式

#### 版本信息
- **组件**：使用 `ListTile` 组件
- **标题**：显示"版本"文本
- **副标题**：显示版本号
- **交互**：保持现有的彩蛋功能（点击5次打开TalkerScreen）

### 卡片样式

```dart
Card(
  elevation: 0,
  shape: S1Shape.cardShape,
  color: colorScheme.surfaceContainerHighest.withValues(alpha: S1Alpha.cardOverlay),
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '主题设置',  // 或 '显示设置'
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // 内容...
      ],
    ),
  ),
)
```

### 颜色选择器设计

```dart
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
            duration: Duration(milliseconds: 200),
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
)
```

### 布局调整

个人资料页面布局调整：
- 将设置卡片移到用户信息卡片下方
- 增加卡片之间的间距：从 `16px` 增加到 `20px`
- 保持整体布局的平衡

```dart
ListView(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  children: [
    _HeaderCard(...),
    if (authState.isLoggedIn && user != null && user.uid.isNotEmpty) ...[
      const SizedBox(height: 16),
      _StatsCard(user: user),
      const SizedBox(height: 16),
      _S1StatsCard(user: user),
      const SizedBox(height: 16),
      _InfoCard(user: user),
    ],
    const SizedBox(height: 20),
    _ThemeSettingsCard(...),
    const SizedBox(height: 16),
    _DisplaySettingsCard(...),
    const SizedBox(height: 16),
    if (authState.isLoggedIn)
      _ActionTile(
        icon: Icons.logout,
        label: '退出登录',
        color: colorScheme.error,
        onTap: () { ... },
      ),
    const SizedBox(height: 24),
  ],
)
```

### 颜色标签映射

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

## 技术实现

### 文件修改

1. **`lib/screens/profile_screen.dart`**：
   - 将 `_SettingsCard` 拆分为 `_ThemeSettingsCard` 和 `_DisplaySettingsCard`
   - 更新 `ProfileBody` 中的布局

2. **`lib/theme/app_theme.dart`**：
   - 保持不变（现有的主题定义已满足需求）

### 组件拆分

#### _ThemeSettingsCard
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
    // 实现主题设置卡片
  }
}
```

#### _DisplaySettingsCard
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
    // 实现显示设置卡片
  }
}
```

## 验证标准

1. **视觉验证**：
   - 两个卡片视觉层次清晰
   - 颜色选择器有标签提示
   - 选中状态有明显的视觉反馈

2. **交互验证**：
   - 颜色选择器点击有动画效果
   - 开关切换流畅
   - 版本信息点击5次能打开TalkerScreen

3. **代码验证**：
   - 通过 `flutter analyze` 无错误
   - 组件拆分合理，职责清晰
   - 保持与现有代码风格一致

4. **多平台验证**：
   - 在 Web 和 Android 上都能正常显示
   - 布局在不同屏幕尺寸下都能正常工作

## 风险评估

1. **低风险**：仅修改UI组件，不涉及业务逻辑
2. **向后兼容**：设置数据结构不变，仅改变UI展示
3. **测试覆盖**：现有的设置功能测试仍然有效

## 时间估算

- 设计文档：已完成
- 实现：约2-3小时
- 测试验证：约1小时
- 总计：约3-4小时
