# 项目宪法
# 本文件补充全局 GEMINI.md，相同条目以本文件为准。

## 项目信息

- **项目名称**：S1 Client（s1_app）
- **核心目标**：第三方 Stage1st（S1）论坛客户端，基于 Flutter 构建，支持多平台运行
- **创建日期**：2026-07-07

---

## 技术栈锁定

> 所有 AI 生成的代码必须严格遵守以下版本，不得引入未列出的主要依赖。

| 层级 | 技术 | 版本 |
|:---|:---|:---|
| 语言 | Dart | >=3.4 <4.0 |
| 框架 | Flutter | >=3.4 |
| 状态管理 | flutter_riverpod | 3.2.1（临时固定；规避 #4765；Notifier / AsyncNotifier；禁长期依赖 `legacy.dart`） |
| HTTP 客户端 | dio | ^5.4.0 |
| 路由 | go_router | ^17.0.0 |
| 本地结构化存储 | drift / drift_flutter | ^2.34.1 / ^0.3.1 |
| 图片磁盘缓存 | flutter_cache_manager / cached_network_image | ^3.4.1 / ^3.4.1 |
| 网络状态 | connectivity_plus | ^6.1.4 |
| 备份（L1 ZIP） | archive / file_selector / share_plus | ^4.0.9 / ^1.1.0 / ^13.2.0 |
| 回复插图 | file_selector + p.sda1.dev 外链图床 | 已有 file_selector；不做 Discuz attach |
| 麻将脸表情 | `assets/emoticons/{*2017}/` 原 png/gif 入库打包 | 对齐 S1-Next；不转 WebP；脚本仅生成/更新 |
| WebView | webview_flutter | ^4.7.0 |
| HTML 渲染 | flutter_html | ^3.0.0 |
| Cookie 管理 | dio_cookie_manager / cookie_jar | ^3.1.1 / ^4.0.8 |
| 安全存储 | flutter_secure_storage | ^10.x |
| 加密 | cryptography | ^2.x |
| 包管理 | flutter pub | — |
| Lint | flutter_lints | ^6.0.0 |
| 运行环境 | Flutter SDK >=3.4 | 支持 Web / Android / iOS / Windows / macOS / Linux |

> Cookie 走 `PersistCookieJar` + 加密存储，不进 Drift、不进 `s1-backup`。不使用 Hive。

---

## Material Design 3 规范

> 所有 Flutter UI 代码必须遵守以下 M3 规则，违者视为 bug。

- **主题**：`useMaterial3: true` + `ColorScheme.fromSeed(seedColor: ...)`，禁手写色板
- **色彩**：UI 绘制一律从 `Theme.of(context).colorScheme` 取语义色
  - **允许**（见下方「M3 允许模式」）：`themeSeeds` 种子色、`Colors.transparent`、API 数据驱动色
  - **禁止**：`screens/` / `widgets/` 中 `Color(0xFF...)`、`Colors.red` 等语义替代
- **排版**：一律 `textTheme.*`；HTML 渲染须从 `textTheme` 桥接到 `flutter_html` 的 `FontSize`
  - **禁止**：裸写 `fontSize: 14` 等常量（头像 fallback 用 `FittedBox` + `textTheme`）
- **组件映射**：`NavigationBar` / `FilledButton` / `SegmentedButton` / 原生 `Badge`
  - 计数/楼层 → `Badge`；可点击标签/分页 → `Chip` / `ActionChip`
- **层级**：`Card` / `AppBar` 必须显式 `elevation: 0`（含继承主题处也应写明）；浮层 Menu/PopupMenu 可按 M3 使用低 elevation
- **透明度**：一律用 `S1Alpha.*` token，禁止内联 `withValues(alpha: 0.x)`
- **排版常量**：`S1Typography.defaultBodySize` 为字号设置标准档，HTML 渲染通过 `S1Typography.bodySize(textTheme)` 桥接

**审计**：`dart run scripts/audit_m3.dart --fail-on-error`（CI / 本地均需通过）

---

## 命名约定

- 文件命名：snake_case（如 `api_service.dart`、`thread_card.dart`）
- 函数/变量命名：camelCase（如 `fetchThreadList`、`isLoggedIn`）
- 类命名：PascalCase（如 `ApiService`、`ThreadCard`）
- 常量命名：camelCase（Dart 惯例，如 `maxRequestsPerSecond`）；全局常量类使用 PascalCase（如 `S1Constants`、`ApiConfig`）
- Provider 命名：camelCase + `Provider` 后缀（如 `authProvider`、`httpClientProvider`）
- Screen 命名：PascalCase + `Screen` 后缀（如 `HomeScreen`、`LoginScreen`）
- Widget 命名：PascalCase，按功能命名（如 `PostItem`、`QuoteBlock`）

---

## 架构边界

- **目录结构**：

```
lib/
├── config/       # 配置常量（API 地址、应用常量、环境变量）
│   ├── api_config.dart       # API 地址与模块名
│   ├── constants.dart        # 应用常量（UA、限速等）
│   ├── env_config.dart       # --dart-define 环境配置（日志、超时等）
│   └── resource_domains.dart # 资源域名规则（代理、认证、公开）
├── models/       # 纯数据模型（不含业务逻辑）
├── providers/    # Riverpod 状态管理（连接 services 与 UI）
├── screens/      # 页面级 Widget（路由目标）
├── services/     # 服务层（HTTP、API 调用、认证）
├── theme/        # Material 3 主题定义
├── utils/        # 工具函数（BBCode 解析等）
├── widgets/      # 可复用 UI 组件
│   ├── s1_error_view.dart    # 统一错误视图（维护/登录/通用）
│   └── ...
├── app.dart      # 应用入口与路由配置
└── main.dart     # 主入口（初始化 Drift / AppLocalData、HTTP 客户端）
```

- **模块职责**：
  - `config/`：只放静态配置，不含逻辑
  - `models/`：纯数据类，包含 `fromJson` 工厂方法，不依赖 Flutter
  - `services/`：封装所有外部交互（HTTP、Cookie、认证、本地 Drift、备份编解码），不依赖 UI 层
  - `providers/`：桥接 services 与 UI，管理状态生命周期，不含直接 HTTP 调用
  - `screens/`：页面组合层，调用 providers 获取数据，不直接调用 services
  - `widgets/`：可复用的 UI 片段，通过参数接收数据，不持有状态逻辑

- **标准数据流**：Screen / Widget → Provider / Notifier → Service → `S1HttpClient` / Dio → Discuz! API，单向，禁止跨层直调
  - Provider / Notifier 负责业务编排及 `loading/data/error`、缓存失效和关联刷新，不能退化为 Service 的无状态透传层
  - 纯 UI 状态（动画、展开收起、输入框、滚动）可留在 Widget；网络、持久化、认证、缓存和业务错误必须下沉
  - 保持最少必要分层，禁止为单一动作叠加无实际职责的 Controller / UseCase / Repository 包装

---

## 禁止模式

> 以下模式在本项目中绝对禁止，发现即指出，不得生成。

- 硬编码 secrets / API Key / 密码（必须走环境变量或配置文件）
- `eval()` 或类似的动态代码执行
- 裸 `catch` 吞掉异常（必须至少记录日志或向用户展示错误信息）
- 在循环内发起 HTTP 请求（N+1 问题）
- 外部 HTTP 请求不设 timeout
- 直接绕过 `S1HttpClient` 发起网络请求（必须走统一的限速与 Cookie 管理）
- 在 Widget 中直接调用 `ApiService`（必须通过 Provider）
- 在 Model 中引入 Flutter 依赖（models 层必须保持纯 Dart）
- 使用 `print()` 进行调试输出（lint 规则 `avoid_print` 已启用）
- 硬编码颜色值 `Color(0xFF...)` 或 `fontSize`（必须从 `colorScheme` / `textTheme` 获取）
- 使用 M2 废弃组件（`RaisedButton`、`BottomNavigationBar`、`ToggleButtons`、手写 `Badge`）
- `Card` / `AppBar` 使用非零 `elevation`（M3 层级靠 Surface Tint，不靠阴影）

---

## 安全边界

- Secrets 管理方式：API 地址硬编码于 `ApiConfig`（公开论坛 API，无密钥）；用户凭据通过 API 登录表单提交，不在客户端持久化明文密码
- 认证方案：Cookie-based（Discuz! 原生 Cookie 认证） + formhash CSRF 防护
- 敏感数据范围：用户 Cookie（auth/session）通过 `PersistCookieJar` 加密存储；用户密码仅在登录请求中传输，不本地持久化
- CSRF 防护：`S1HttpClient` 自动从响应提取 formhash 并注入后续 POST 请求
- 速率限制：`S1HttpClient` 内置每秒最多 2 个请求的限速，保护 S1 服务器

---

## 环境变量配置（--dart-define）

> 所有可通过环境调整的参数统一在 `lib/config/env_config.dart` 中定义，通过 Flutter `--dart-define` 在编译期注入，零依赖。

```bash
# 默认（仅错误日志）
flutter run -d chrome

# 查看所有请求日志
flutter run -d chrome --dart-define=TALKER_LOG_LEVEL=all

# 关闭 Talker
flutter run -d chrome --dart-define=TALKER_ENABLED=false

# 组合
flutter run -d chrome --dart-define=TALKER_LOG_LEVEL=all --dart-define=TALKER_MAX_HISTORY=1000
```

| Key | 类型 | 默认值 | 说明 |
|:---|:---|:---|:---|
| `TALKER_ENABLED` | bool | `true` | Talker 日志总开关 |
| `TALKER_LOG_LEVEL` | String | `error` | `error` 仅错误 / `all` 全部 |
| `TALKER_MAX_HISTORY` | int | `500` | Talker 历史记录上限 |
| `PROXY_PORT` | int | `19080` | Web CORS 代理端口 |
| `CONNECT_TIMEOUT` | int | `20` | Dio 连接超时（秒） |
| `RECEIVE_TIMEOUT` | int | `30` | Dio 响应超时（秒） |
| `SEND_TIMEOUT` | int | `30` | Dio 发送超时（秒） |
| `IMAGE_UPLOAD_TIMEOUT` | int | `120` | 外链图床上传 send/receive 超时（秒；Web 代理 `/ext-upload` 同上限） |

新增配置项规则：
1. 在 `EnvConfig` 中添加 `static const` 字段，使用 `Xxx.fromEnvironment('KEY', defaultValue: ...)` 
2. 使用处引用 `EnvConfig.xxx`，禁止硬编码
3. 代理端口需与 `scripts/proxy_server.dart` 保持一致

---

## 完成标准（Definition of Done）

一个功能被认为"完成"，必须同时满足：

- 核心路径有自动化测试覆盖（`flutter test`）
- 异常路径（网络超时、API 错误、空数据）已处理并有用户友好提示
- 无 [CRITICAL] 级别审计问题
- 已原子提交，commit message 符合 Angular 规范（`<type>(<scope>): <subject>`）
- 通过 `flutter analyze` 无 error/warning（analysis_options.yaml 规则）
- 多平台兼容性已考虑（至少 Web + Android 双平台验证关键路径）

---

## 当前已知约束

> 记录项目中已知的技术债或暂时妥协，避免 AI 重复提出或错误优化。

- flutter_html 已对齐稳定 `^3.0.0`；大版本升级时仍需回归帖子 HTML/BBCode 渲染
- Web 端受 CORS 限制，开发时需启动 `scripts/proxy_server.dart` 代理服务器
- 登录流程：全平台统一走 API 表单登录（`ApiService.login()`）；Web 端需配合 CORS 代理
- 本地结构化数据（settings / reading_history / poll_votes / blacklist 表）走 Drift；Cookie 走加密 `PersistCookieJar`。无 Hive。
- Native 图片使用 `flutter_cache_manager` 磁盘缓存；Web 主要依赖浏览器缓存。备份**禁止**包含图片缓存
- 跨客户端备份格式：`docs/backup-format-v1.md`（默认仅 L1 JSON ZIP；`native/` L2 可选且未作为默认导出）
- 黑名单：本地黑名单 MVP 已实现（Drift + 设置页管理 + 楼层加入；`scope`：`thread` 滤主题列表、`post` 折叠楼层、`pm` 预留）。不做服务端网页黑名单同步 / 屏蔽词表。
- 麻将脸：对齐 S1-Next，原 png/gif **入库**于 `assets/emoticons/{face2017|carton2017|…}/` 并随客户端打包；不转 WebP。`scripts/download_emoticons.dart` 仅用于生成/增量更新资源与 `manifest.json` 后提交，不是「clone 后必跑才能构建」的前置。读帖/面板 **local-first**，缺失时再 CDN（Web 走 `/img-proxy`）。
- test 目录覆盖率仍不足，尤其是 screens 和 widgets 层
- 技术栈现代化定案与拆分：`docs/plans/2026-07-12-tech-stack-modernization.md`（P0–P6 已落地后以本文件锁定表为准）
- flutter_riverpod 临时固定为 `3.2.1`：`3.3.2` 存在上游 [#4765](https://github.com/rrousselGit/riverpod/issues/4765) 的 Provider 订阅恢复期 `markNeedsBuild` 回归；升级前必须先通过路由 Provider 链回归测试。

### M3 允许模式

> 下列模式**合规**，不是 bug；审计脚本已排除或仅 WARN。

| 模式 | 位置 | 说明 |
|:---|:---|:---|
| `themeSeeds` 中 `Color(0xFF...)` | `lib/theme/app_theme.dart` | 仅作 `ColorScheme.fromSeed` 输入；色板预览（`theme_color_picker`）可直接渲染种子色 |
| `Colors.transparent` | SegmentedButton 未选中段、bbcode `.hide-content`、poll 未选中底 | 表示「无底色」，不是语义色替代 |
| Menu/PopupMenu `elevation: 3` | `lib/theme/app_theme.dart` | M3 浮层菜单规范；与 Card/AppBar 零阴影规则无关 |
| 装饰性 `BoxShadow` | `theme_color_picker.dart` 选中色块高亮 | 非 Card/AppBar elevation；阴影色用 `S1Alpha.cardOverlay` |
| API 投票色（对比度校验后） | `lib/utils/poll_bar_color.dart` | 优先 API `#RRGGBB`；对 `surfaceContainerHighest` 不足 3:1 时回退 `scheme.primary` |
| 交互/只读 `Chip` | 分类标签、分页、`ActionChip` | M3 合法；纯计数/状态角标用 `Badge` |

### M3 技术债

> 当前无未偿还项。Widget 测试须使用 `AppTheme` 或 `test/helpers/test_theme.dart` 的 `wrapWithAppTheme`。

---

## Cursor Cloud specific instructions

> 面向后续 Cloud Agent 的持久化环境说明（依赖已由 update script `flutter pub get` 自动刷新，此处只记录非显而易见的启动/运行注意事项）。

- **Flutter SDK**：预装在 `/home/ubuntu/flutter`（stable，Dart 3.12+），已通过 `~/.bashrc` 加入交互式 shell 的 PATH。非交互式脚本请用全路径 `/home/ubuntu/flutter/bin/flutter`。
- **Lint / Test**：`flutter analyze`（当前 0 issue）与 `flutter test`（250+ 测试）。注意：**首次** `flutter test` 会一次性编译引擎测试产物，可能数分钟无输出（输出被 shell 缓冲），属正常；产物缓存后整套测试约数秒到十几秒。用 `--reporter expanded` 可看到实时进度。
- **M3 审计**：`dart run scripts/audit_m3.dart --fail-on-error` 扫描 `lib/`（P0/P1）与 `test/`，报告输出至 `reports/m3_audit_<date>.md`。
- **运行 Web 开发环境（推荐的可测试目标）**：需要同时启动两个进程（标准命令见 `README.md`）：
  1. CORS 代理：`dart run scripts/proxy_server.dart`，监听 `http://localhost:19080`，转发到 `https://stage1st.com/2b/...` 并处理 CORS/Cookie。
  2. Flutter Web：`flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`（无头 VM 用 `web-server` 设备，避免依赖 Chrome 调试扩展；桌面 Chrome 可直接访问 `http://localhost:8080`）。
  Web 端 API 请求由 `S1HttpClient` 在 `kIsWeb` 时重写到代理端口，**代理必须先启动**，否则论坛数据加载失败。
- **登录门控**：论坛浏览相关 Tab 需登录；未登录显示登录引导。Web 端登录走 API 表单；游客 API 仍可用于服务层/代理验证。完整登录管线已验证：无效凭据返回 `mobile:login_invalid`。
- **网络**：`stage1st.com` 在本环境可直连（游客 API 可读取版块数据）。
- **⚠️ 测试账号是用户多年的真实账号，务必谨慎**：`S1_TEST_USERNAME` / `S1_TEST_PASSWORD` 对应的是用户长期使用的真实 S1 账号。**严禁频繁登录、暴力重试或高频请求**，否则可能触发风控导致账号被封，造成用户重大损失。原则：
  - 优先用**游客 API**（`module=forumindex` / `forumdisplay` / `viewthread` 无需登录即可读取）做验证，尽量不登录。
  - 确需登录时，一次成功即可；`scripts/proxy_server.dart` 会在内存中保存已登录的 S1 Cookie 并自动附加到后续所有上游请求，因此**登录一次后无需重复登录**，浏览器端刷新页面即可通过 `checkSession()` 复用会话。
  - 切勿写循环/压测脚本调用登录接口；`S1HttpClient` 自带每秒 2 请求限速，不要绕过。
