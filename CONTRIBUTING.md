# 贡献指南

感谢你考虑为 S1er 做贡献。开始较大改动前，建议先创建 Issue 对齐范围，避免重复实现。

## 流程

1. Fork 仓库并从最新 `main` 创建分支。
2. 只提交与问题直接相关的改动，并为行为变化补充测试。
3. 运行下方「质量关卡」。
4. Commit 遵循 Angular 格式（见下）。
5. Pull Request 中说明问题、方案、验证结果、平台影响与必要截图。

本地开发环境、Web 代理与 `--dart-define` 见 [开发指南](docs/development.md)。架构与分层约束见 [架构说明](docs/architecture.md)。

## Commit 规范

格式：`<type>(<scope>): <中文主题>`

- **类型**：`feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`chore`
- **scope**：必填（如 `thread`、`auth`、`docs`）

示例：`fix(thread): 修复楼层定位偏移`

## 质量关卡

提交前至少运行：

```bash
dart format --output=none --set-exit-if-changed lib test scripts
flutter analyze
flutter test
dart run scripts/audit_m3.dart --fail-on-error
```

涉及平台或依赖变更时，再执行对应构建：

```bash
flutter build web
flutter build apk --release
```

分享卡导出：Native 依赖 `ironpress`（预编译 mozjpeg / oxipng / libwebp）；默认 WebP，可选 JPEG / PNG。Web 走浏览器 `canvas.toBlob` 或引擎 PNG。

## Pre-commit（推荐）

安装后，每次 `git commit` 会跑质量检查；失败则阻止提交：

```bash
.\scripts\install_precommit.ps1     # Windows
```

| 模式 | 用法 | 检查项 |
|------|------|--------|
| **full**（默认） | `git commit -m "..."` | format + analyze + test + M3 |
| **lite** | `$env:S1_PRECOMMIT="lite"; git commit -m "..."` | 仅 format + analyze（小改小修） |
| **skip** | `$env:S1_PRECOMMIT="skip"; git commit -m "..."` 或 `git commit --no-verify` | 跳过全部 |

钩子是指向 `scripts/pre-commit-hook.sh` 的薄包装，改脚本后一般不必重装。

## 报告缺陷

请附上：

- 复现步骤
- 预期结果与实际结果
- Flutter 版本与目标平台
- 已脱敏的日志（Talker 等）

请勿公开提交账号、密码、Cookie 或其他个人信息。

## 安全漏洞

应优先通过 GitHub 的私密安全报告渠道告知维护者，不要在公开 Issue 中披露利用细节。

对真实论坛接口做手动探测时，请控制频率并优先使用游客只读接口；勿对真实账号循环登录或高频写操作。详见 [开发指南](docs/development.md#论坛接口探测)。
