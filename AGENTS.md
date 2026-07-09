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
| 状态管理 | flutter_riverpod | ^2.5.0 |
| HTTP 客户端 | dio | ^5.4.0 |
| 路由 | go_router | ^14.0.0 |
| 本地存储 | hive / hive_flutter | ^2.2.3 / ^1.1.0 |
| WebView | webview_flutter | ^4.7.0 |
| HTML 渲染 | flutter_html | ^3.0.0-beta.2 |
| Cookie 管理 | dio_cookie_manager / cookie_jar | ^3.1.1 / ^4.0.8 |
| 包管理 | flutter pub | — |
| 运行环境 | Flutter SDK >=3.4 | 支持 Web / Android / iOS / Windows / macOS / Linux |

---

## Material Design 3 规范

> 所有 Flutter UI 代码必须遵守以下 M3 规则，违者视为 bug。

- **主题**：`useMaterial3: true` + `ColorScheme.fromSeed(seedColor: ...)`，禁用手写色板
- **色彩**：一律从 `Theme.of(context).colorScheme` 取语义色（`.primary`、`.surface` 等）
- **排版**：一律用 `textTheme.*` 标准层级，禁用 `fontSize` 裸写
- **组件映射**：`NavigationBar`(替代 BottomNavigationBar) / `FilledButton`(替代 RaisedButton/ElevatedButton) / `SegmentedButton`(替代 ToggleButtons) / 原生 `Badge` 组件
- **层级**：`elevation: 0` 为默认，区分靠 Surface Tint

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
├── config/       # 配置常量（API 地址、应用常量）
├── models/       # 纯数据模型（不含业务逻辑）
├── providers/    # Riverpod 状态管理（连接 services 与 UI）
├── screens/      # 页面级 Widget（路由目标）
├── services/     # 服务层（HTTP、API 调用、认证）
├── theme/        # Material 3 主题定义
├── utils/        # 工具函数（BBCode 解析等）
├── widgets/      # 可复用 UI 组件
├── app.dart      # 应用入口与路由配置
└── main.dart     # 主入口（初始化 Hive、HTTP 客户端）
```

- **模块职责**：
  - `config/`：只放静态配置，不含逻辑
  - `models/`：纯数据类，包含 `fromJson` 工厂方法，不依赖 Flutter
  - `services/`：封装所有外部交互（HTTP、Cookie、认证），不依赖 UI 层
  - `providers/`：桥接 services 与 UI，管理状态生命周期，不含直接 HTTP 调用
  - `screens/`：页面组合层，调用 providers 获取数据，不直接调用 services
  - `widgets/`：可复用的 UI 片段，通过参数接收数据，不持有状态逻辑

- **数据流方向**：Screen → Provider → Service → Dio HTTP → Discuz! API，单向，禁止跨层直调

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

- Secrets 管理方式：API 地址硬编码于 `ApiConfig`（公开论坛 API，无密钥）；用户凭据通过 WebView 登录流程处理，不在客户端存储明文密码
- 认证方案：Cookie-based（Discuz! 原生 Cookie 认证） + formhash CSRF 防护
- 敏感数据范围：用户 Cookie（auth/session）通过 `PersistCookieJar` 加密存储；用户密码仅在 WebView 内传输，不经过应用代码
- CSRF 防护：`S1HttpClient` 自动从响应提取 formhash 并注入后续 POST 请求
- 速率限制：`S1HttpClient` 内置每秒最多 2 个请求的限速，保护 S1 服务器

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

- flutter_html 使用 beta 版本（^3.0.0-beta.2），API 可能不稳定，升级时需谨慎
- Web 端受 CORS 限制，开发时需启动 `scripts/proxy_server.dart` 代理服务器
- 登录流程平台分化：原生平台走 WebView，Web 平台走 API 表单登录，两套逻辑需同时维护
- Hive 用于本地存储（cookies / settings / cache），未做加密，生产环境可考虑迁移到 hive 加密 box 或 flutter_secure_storage
- 表情包资源通过脚本从 GitHub 下载（`scripts/download_emoticons.dart`），未内置到仓库
- test 目录已有基础测试，但覆盖率不足，尤其是 screens 和 widgets 层

---

## Cursor Cloud specific instructions

> 面向后续 Cloud Agent 的持久化环境说明（依赖已由 update script `flutter pub get` 自动刷新，此处只记录非显而易见的启动/运行注意事项）。

- **Flutter SDK**：预装在 `/home/ubuntu/flutter`（stable，Dart 3.12+），已通过 `~/.bashrc` 加入交互式 shell 的 PATH。非交互式脚本请用全路径 `/home/ubuntu/flutter/bin/flutter`。
- **Lint / Test**：`flutter analyze`（当前 0 issue）与 `flutter test`（80 个测试全绿）。注意：**首次** `flutter test` 会一次性编译引擎测试产物，可能数分钟无输出（输出被 shell 缓冲），属正常；产物缓存后整套测试约 6s。用 `--reporter expanded` 可看到实时进度。
- **运行 Web 开发环境（推荐的可测试目标）**：需要同时启动两个进程（标准命令见 `README.md`）：
  1. CORS 代理：`dart run scripts/proxy_server.dart`，监听 `http://localhost:19080`，转发到 `https://stage1st.com/2b/...` 并处理 CORS/Cookie。
  2. Flutter Web：`flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`（无头 VM 用 `web-server` 设备，避免依赖 Chrome 调试扩展；桌面 Chrome 可直接访问 `http://localhost:8080`）。
  Web 端 API 请求由 `S1HttpClient` 在 `kIsWeb` 时重写到代理端口，**代理必须先启动**，否则论坛数据加载失败。
- **登录后才能浏览**：`home_screen.dart` 将论坛 Tab 用 `isLoggedIn` 门控，未登录仅显示"登录后即可浏览"提示；Web 端登录走 API 表单（用户名+密码 → formhash → POST）。要端到端演示浏览版块/主题需要**有效的 S1 论坛账号**。完整登录管线（formhash/CSRF + 代理 + 实时 `stage1st.com`）已验证可用：用无效凭据会正确返回 `mobile:login_invalid`。
- **网络**：`stage1st.com` 在本环境可直连（游客 API 可读取版块数据）。
- **⚠️ 测试账号是用户多年的真实账号，务必谨慎**：`S1_TEST_USERNAME` / `S1_TEST_PASSWORD` 对应的是用户长期使用的真实 S1 账号。**严禁频繁登录、暴力重试或高频请求**，否则可能触发风控导致账号被封，造成用户重大损失。原则：
  - 优先用**游客 API**（`module=forumindex` / `forumdisplay` / `viewthread` 无需登录即可读取）做验证，尽量不登录。
  - 确需登录时，一次成功即可；`scripts/proxy_server.dart` 会在内存中保存已登录的 S1 Cookie 并自动附加到后续所有上游请求，因此**登录一次后无需重复登录**，浏览器端刷新页面即可通过 `checkSession()` 复用会话。
  - 切勿写循环/压测脚本调用登录接口；`S1HttpClient` 自带每秒 2 请求限速，不要绕过。
