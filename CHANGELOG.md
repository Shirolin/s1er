# Changelog

All notable changes to S1er will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **版本约定**：Beta 阶段使用 `0.x`（见 `docs/release/README.md`）；当前 `0.1.0`
- **Pre-commit**：支持环境变量 `S1_PRECOMMIT`（`full` 默认全量 / `lite` 仅 format+analyze / `skip` 跳过）；钩子委托 `scripts/pre-commit-hook.sh`，详见 README
- **README**：与当前代码能力对齐（功能清单、`--dart-define`、代理/脚本说明与文档链接）

## [0.1.0] - 2026-07-15

### Added

- **论坛浏览**：版块列表、主题列表、主题详情、分页浏览、页码跳转与楼层定位
- **内容渲染**：BBCode 解析与渲染（引用、代码、列表、链接、图片）、S1 麻将脸表情显示、帖子图片查看器
- **账号会话**：API 表单登录（含安全提问）、登录状态持久化、退出登录与个人资料
- **发帖互动**：回复、引用回复、发表新主题、编辑帖子、投票、评分（加分/扣分）、楼层举报；回复插图经 `p.sda1.dev` 外链图床（不做 Discuz 附件）
- **搜索**：主题搜索与用户搜索，支持分页（Discuz 常见约 30 秒冷却）
- **收藏与关系**：主题/版块收藏、好友列表、每日签到、小黑屋（暗室）记录
- **消息中心**：私信列表与会话、系统提醒查看
- **用户空间**：查看他人主题与回复列表、用户资料卡片
- **本地体验**：阅读历史与进度、回复草稿自动保存与恢复、投票状态本地缓存、主题切换、多套种子色、字号缩放、发帖小尾巴、分享卡导出（默认 WebP）
- **图片策略**：按网络状态选择加载策略（WiFi/移动数据/离线）、原生磁盘缓存、缓存上限查看与清理
- **黑名单**：本地主题/楼层/私信屏蔽，支持从 S1 网页黑名单只读导入（不反向写入）
- **数据备份**：导入/导出 L1 JSON ZIP（阅读历史、设置、黑名单、投票记录等），不含 Cookie、密码或图片缓存
- **应用升级**：拉取公开 `latest.json` 清单并提示更新（关于页可手动检查）
- **Material Design 3**：亮色/深色主题，多套预设种子色，M3 语义色与排版 token 驱动全界面
- **诊断能力**：Talker 应用内日志查看器；可选 Sentry（`--dart-define=SENTRY_DSN`）

### Infrastructure

- **Material 3 合规审计脚本**：`scripts/audit_m3.dart`
- **Web CORS 开发代理**：`scripts/proxy_server.dart`（含 Cookie、图片与图床 `/ext-upload`）
- **持续质量检查**：Git pre-commit hook（默认 dart format + flutter analyze + flutter test + M3 audit；可用 `S1_PRECOMMIT=lite|skip`）
- **崩溃监控**：可选 Sentry 集成（通过 `--dart-define=SENTRY_DSN` 注入）

### Platform Support

- Web（需本地 CORS 代理）
- Android
- iOS（代码已就绪，待签名与真机测试）
- Windows
- macOS（代码已就绪，待签名与真机测试）
- Linux

### Known Limitations

- 搜索有约 30 秒冷却间隔（Discuz! 接口限制）
- 黑名单仅本地生效；网页导入为只读，不同步写回论坛
- 部分功能依赖 Stage1st 论坛的游客/登录权限
- Web 端受浏览器 CORS 限制，需配合本地代理运行
- 推送通知尚未实现
- 国际化和无障碍仍在规划中
