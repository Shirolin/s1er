# Changelog

All notable changes to S1 Client will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-15

### Added

- **论坛浏览**：版块列表、主题列表、主题详情、分页浏览、页码跳转与楼层定位
- **内容渲染**：BBCode 解析与渲染（引用、代码、列表、链接、图片）、S1 麻将脸表情显示、帖子图片查看器
- **账号会话**：API 表单登录（含安全问答）、登录状态持久化、退出登录
- **互动功能**：回复帖子、引用回复、发表新主题、编辑帖子、投票、评分（加分/扣分）、收藏主题与版块
- **消息中心**：私信列表与对话、系统提醒查看
- **用户空间**：查看他人主题与回复列表、用户资料卡片
- **搜索**：主题搜索与用户搜索，支持分页
- **本地功能**：阅读历史与进度记录、回复草稿自动保存与恢复、投票状态本地缓存、主题切换、多套种子色、字号缩放
- **图片策略**：按网络状态选择加载策略（WiFi/移动数据/离线）、原生磁盘缓存、缓存上限查看与清理
- **数据备份**：导入/导出 L1 JSON ZIP 格式（阅读历史、设置、黑名单、投票记录），不包含 Cookie 或图片缓存
- **黑名单**：本地主题/楼层/私信屏蔽，支持从 S1 网页黑名单只读导入
- **暗室（小黑屋）**：查看论坛处罚记录
- **每日签到**：论坛每日打卡
- **Material Design 3**：亮色/深色主题，5 套预设种子色，M3 语义色与排版 token 驱动全界面
- **诊断能力**：Talker 应用内日志查看器

### Infrastructure

- **Material 3 合规审计脚本**：`scripts/audit_m3.dart`
- **Web CORS 开发代理**：`scripts/proxy_server.dart`
- **持续质量检查**：Git pre-commit hook（dart format + flutter analyze + flutter test + M3 audit）
- **崩溃监控**：可选 Sentry 集成（通过 `--dart-define=SENTRY_DSN` 注入）

### Platform Support

- Web（需本地 CORS 代理）
- Android
- iOS（代码已就绪，待签名与真机测试）
- Windows
- macOS（代码已就绪，待签名与真机测试）
- Linux

### Known Limitations

- 搜索有 30 秒冷却间隔（Discuz! 接口限制）
- 部分功能依赖 Stage1st 论坛的游客/登录权限
- Web 端受浏览器 CORS 限制，需配合本地代理运行
- 推送通知尚未实现
- 国际化和无障碍仍在规划中
