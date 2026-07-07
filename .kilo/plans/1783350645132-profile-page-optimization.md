# 优化个人页面 — 实施计划

## 背景

用户反馈两个问题：

1. **主题设置不生效**：`app.dart:59` 硬编码 `ThemeMode.system`，profile 页的 `darkMode` 开关改变 Hive 存储但 `S1App` 从未读取，开关形同虚设。
2. **统计信息重复 & 全零**：`_InfoCard`（UID/积分/帖子数/主题数）与 `_StatsCard`（积分/帖子/主题/好友）中积分、帖子、主题重复显示。且 `getUserProfile()`（`api_service.dart:261-285`）仅从 `forumindex` 接口提取 `member_credits`，未提取 posts/threads/friends，导致这三项始终为 0。

## 决策

### 1. 主题模式：三态 SegmentedButton（跟随系统 / 浅色 / 深色）

**理由**：用户提出 on/off 开关切深浅色，但"跟随系统"是移动端标配选项。三态 SegmentedButton 是 Material 3 推荐方案，比两个 Switch 更直观。

**实现**：
- `settings_provider.dart`：`bool darkMode` → `String themeMode`（'system'/'light'/'dark'），默认 'system'
- `app.dart`：`S1App` 改为 `ConsumerWidget`，读取 `settingsProvider.themeMode` 映射为 `ThemeMode`
- `profile_screen.dart`：`_SettingsCard` 中 `SwitchListTile('深色模式')` → `SegmentedButton` 三态选择

**Hive 迁移**：`_loadSettings` 中读取旧 `darkMode` bool 值做一次性迁移——`true` → 'dark'，`false` → 'system'（原默认行为是跟随系统）。

### 2. 消除重复信息

**实现**：
- `_InfoCard` 移除积分/帖子数/主题数，仅保留 UID
- `_StatsCard` 保留积分/帖子/主题/好友（与 API 数据对应）

### 3. 处理 posts/threads/friends 为零

**根因**：`getUserProfile()` 调用 `forumindex` 模块，该模块不返回用户帖子/主题/好友数。Discuz! 获取完整用户资料的接口是 `my` 模块（`module=my`），当前 `ApiConfig` 未配置。

**实现**：
- `api_config.dart`：新增 `moduleMy = 'my'`
- `api_service.dart`：`getUserProfile()` 保持现有逻辑不变（forumindex 提供 uid/username/avatar/groupTitle/credits/groupid），额外调用 `module=my` 获取 posts/threads/friends，合并到 User 对象
- 若 `module=my` 调用失败，降级为仅显示积分（当前行为）

## 涉及文件

| 文件 | 改动 |
|------|------|
| `lib/providers/settings_provider.dart` | `bool darkMode` → `String themeMode`，Hive 迁移逻辑 |
| `lib/app.dart` | `S1App` → `ConsumerWidget`，读取 themeMode |
| `lib/screens/profile_screen.dart` | SegmentedButton 替换 Switch，移除 `_InfoCard` 中重复项 |
| `lib/config/api_config.dart` | 新增 `moduleMy` |
| `lib/services/api_service.dart` | `getUserProfile()` 补充 posts/threads/friends |

## 风险

- **`module=my` API 字段不确定**：Discuz! `my` 模块返回的 `Variables.space` 中应包含 `posts`/`threads`/`friends`，但不同 Discuz! 版本字段名可能不同。实现时需先手动请求一次确认字段名，若不存在则降级。
- **Hive 旧数据迁移**：`themeMode` 是新 key，`_loadSettings` 需处理 `box.get('themeMode')` 为 null 的情况，此时检查旧 `darkMode` key 做一次性迁移。

## 验证

1. 主题切换：进入个人页 → 切换三种模式 → 返回首页确认主题跟随变化
2. 重启持久化：切换到深色 → 杀掉 app → 重启确认仍为深色
3. Hive 迁移：旧版本（darkMode=true）升级后应自动变为 'dark'
4. 统计数据：登录后个人页积分/帖子/主题/好友显示正确数值（非零）
5. 降级：若 `module=my` 接口不可用，统计卡片隐藏或仅显示积分
