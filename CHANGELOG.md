# Changelog

All notable changes to S1er will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.3] - 2026-07-24

### Changed

- **更新检查优化**：CDN 作为默认主节点，镜像源并发竞态拉取，5 秒短超时隔离
- **最低版本提升**：minSupported 提高至 0.3.2，老版本将强制更新
- **冷却修复**：根治历史 null 版本号冷却误判

## [0.3.2] - 2026-07-24

### Fixed

- **更新冷却隔离**：不同版本号的更新提示互不干扰，新版本会立即弹窗
- **手动检查空版本漏洞**：修复手动检查更新时版本号注入的空值问题

## [0.3.1] - 2026-07-24

### Added

- **边界结束引导**：列表翻至末页/末尾时显示引导文字（「本页到底 · 左滑或点下一页」、「已是末页」等），结合触感反馈与 SnackBar 提示
- **客户端本地搜索**：支持在当前列表页内实时过滤，搜索栏显示匹配数，高亮关键词
- **应用内变更日志**：版本升级后首次启动自动弹出新功能摘要，设置页可查看完整版本历史

### Changed

- 应用内更新直链修复与发版流程优化

## [0.3.0] - 2026-07-24

### Added

- **论坛附件插图**：发帖/回复/编辑默认走 Discuz `swfupload`（`[attachimg]` + 网页提交 `attachnew`）；可切换外链 `p.sda1.dev`；默认压缩最长边约 2000px；失败可「改用外链」重试
- **多楼层分享**：跨页选择、分块捕获与 Isolate 拼接
- **BBCode 工具栏**：添加常用 BBCode 快捷按钮与键盘快捷键
- **批量图片上传**：支持多图批量上传、剪贴板粘贴与字数统计
- **版块收藏与屏蔽**：首页分类重构，支持收藏/屏蔽版块
- **列表密度切换**：设置页可切换紧凑/舒适列表密度，SnackBar M3 重构
- **自定义字体**：支持用户导入自定义字体
- **发帖预览**：预览直接提交、引用摘要折叠、表情面板高度对齐
- **ABI 分架构 APK 下载**：升级提醒可选 arm64-v8a / armeabi-v7a / x86_64 分架构包
- **帖子跳转**：帖子详情菜单添加「跳转到最新」功能
- **封禁回复识别**：支持服务端封禁账号回复的识别与引用回溯
- **古早链接解析**：支持解析 `read-htm-tid` 格式的老帖子链接

### Changed

- **Compose 流程重构**：附件上传、工具栏、预览、批量图片全链路梳理

### Fixed

- **Compose 楼层断言**：识别编辑成功响应，规避未 layout 楼层断言
- **菜单可见性**：默认显示「在浏览器打开」菜单项

## [0.2.0] - 2026-07-19

### Changed

- **BBCode 重构**：parser 与 renderer 重写，新增 HTML optimizer；移除 quote_block widget
- **未读计数**：新增 unread_count 模型与 provider，首页显示未读数
- **分享卡**：新增 share_card widget，支持导出分享图
- **桌面菜单**：app_bar_more_menu 增强，支持更多操作
- **错误监控**：Sentry bootstrap 精简，error_hub 统一错误处理
- **性能优化**：图片查看器懒加载、HTML 解析缓存、moyu benchmark

## [0.1.3] - 2026-07-19

### Changed

- 构建与发版流程优化；内容与 0.1.1 一致

## [0.1.2] - 2026-07-19

### Changed

- 构建与发版流程优化；内容与 0.1.1 一致

## [0.1.1] - 2026-07-19

### Changed

- **平台验收**：Windows 标为已验证（与 Web / Android 并列）；同步 README、宣传站与 AGENTS 完成标准
- **读帖性能**：评分 HTML 进程内会话缓存去重（Mobile `postlist` 无楼层 `rate`，不能按 JSON 跳过）；图片与 API 限速分桶但均为 2/s；楼层行级订阅黑名单/登录态；PostItem 全量 keep-alive（优先不卡顿）；BBCode 作者色与大页解析可走缓存/isolate；分享卡大图 RGBA 合成下沉 isolate；表情面板可见区再解码；Drift 为阅读历史/投票增加 `uid` 索引
- **版本约定**：Beta 阶段使用 `0.x`（见 `docs/release/README.md`）；当前 `0.1.0`
- **Pre-commit**：支持环境变量 `S1_PRECOMMIT`（`full` 默认全量 / `lite` 仅 format+analyze / `skip` 跳过）；钩子委托 `scripts/pre-commit-hook.sh`，详见 [CONTRIBUTING.md](CONTRIBUTING.md) / [docs/development.md](docs/development.md)
- **文档分流**：README 瘦身为产品入口（截图、下载、亮点、短快速开始）；贡献流程 → [CONTRIBUTING.md](CONTRIBUTING.md)；代理与 `--dart-define` → [docs/development.md](docs/development.md)；架构 → [docs/architecture.md](docs/architecture.md)

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

- Web（需本地 CORS 代理；已验证）
- Android（已验证 · APK）
- Windows（已验证 · zip x64）
- iOS（代码已就绪，待签名与真机测试）
- macOS（代码已就绪，待签名与真机测试）
- Linux（代码已就绪，待系统验收）

### Known Limitations

- 搜索有约 30 秒冷却间隔（Discuz! 接口限制）
- 黑名单仅本地生效；网页导入为只读，不同步写回论坛
- 部分功能依赖 Stage1st 论坛的游客/登录权限
- Web 端受浏览器 CORS 限制，需配合本地代理运行
- 推送通知尚未实现
- 国际化和无障碍仍在规划中
