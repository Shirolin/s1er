# S1 Client

第三方 Stage1st（S1）论坛客户端，基于 Flutter 构建，支持多平台运行。

## 功能

- **版块浏览** — 查看 S1 论坛的所有版块分类与子版块
- **帖子列表** — 浏览版块内主题，支持分页与页码跳转
- **帖子详情** — 查看主题回复内容，支持分页
- **BBCode 渲染** — 解析粗体、斜体、下划线、删除线、颜色、大小、图片、链接、引用、代码、列表、表情等 BBCode 标签
- **用户登录** — 原生平台通过 WebView 完成 Discuz! 登录并同步 Cookie；Web 端通过 API 表单登录
- **发帖回复** — 登录后可回复主题
- **用户资料** — 查看个人资料（积分、帖子数、主题数、用户组）
- **深色模式** — 跟随系统主题或手动切换
- **图片查看** — 点击放大查看帖子内图片，支持手势缩放
- **表情支持** — 渲染 S1 论坛专用表情
- **Cookie 持久化** — 登录状态持久保存，下次启动自动恢复

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter (>=3.4) |
| 状态管理 | flutter_riverpod |
| 路由 | go_router |
| HTTP 请求 | dio + dio_cookie_manager |
| Cookie 管理 | cookie_jar (PersistCookieJar) |
| 本地存储 | hive / hive_flutter |
| WebView | webview_flutter |
| 图片加载 | cached_network_image |
| BBCode 渲染 | flutter_html + 自定义解析器 |
| 平台支持 | Web / Android / iOS / Windows / macOS / Linux |

## 项目结构

```
lib/
├── config/              # 配置
│   ├── api_config.dart      # API 地址与模块名
│   └── constants.dart       # 应用常量（UA、限速等）
├── models/              # 数据模型
│   ├── emoticon.dart        # 表情映射
│   ├── forum_category.dart  # 版块分类
│   ├── post.dart            # 回复
│   ├── thread.dart          # 主题
│   └── user.dart            # 用户
├── providers/           # Riverpod 状态管理
│   ├── auth_provider.dart       # 登录状态
│   ├── forum_list_provider.dart # 版块列表
│   ├── post_provider.dart       # 帖子内容
│   ├── settings_provider.dart   # 应用设置
│   └── thread_list_provider.dart# 主题列表
├── screens/             # 页面
│   ├── home_screen.dart        # 首页（版块导航）
│   ├── forum_list_screen.dart  # 版块主题列表
│   ├── thread_detail_screen.dart# 帖子详情
│   ├── login_screen.dart       # 登录页
│   ├── compose_screen.dart     # 发帖/回复
│   └── profile_screen.dart     # 个人资料
├── services/            # 服务层
│   ├── http_client.dart        # HTTP 客户端（限速、formhash 注入、Cookie 管理）
│   ├── api_service.dart        # Discuz! API 封装
│   ├── auth_service.dart       # 登录/登出/会话管理
│   └── formhash_service.dart   # Formhash 管理
├── theme/               # 主题
│   ├── app_theme.dart          # Material 3 主题
│   └── colors.dart             # 品牌色
├── utils/               # 工具
│   └── bbcode_parser.dart      # BBCode → HTML 解析
├── widgets/             # 组件
│   ├── bbcode_renderer.dart    # BBCode 渲染组件
│   ├── emoticon_widget.dart    # 表情组件
│   ├── image_viewer.dart       # 图片查看器
│   ├── post_item.dart          # 回复卡片
│   ├── quote_block.dart        # 引用块
│   ├── thread_card.dart        # 主题卡片
│   └── web_avatar.dart         # 跨平台头像组件
├── app.dart             # 应用入口与路由
└── main.dart            # 主入口（Hive 初始化、HTTP 客户端初始化）
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.4
- Dart SDK >= 3.4

### 安装与运行

```bash
# 获取依赖
flutter pub get

# 运行（桌面/移动端原生）
flutter run

# 运行（Web 端，需要 CORS 代理）
./scripts/start_dev.ps1
```

### Web 端开发

由于 S1 的 Discuz! API 存在 CORS 限制，Web 端开发时需要启动代理服务器：

```bash
dart run scripts/proxy_server.dart
```

代理运行在 `http://localhost:19080`，会自动转发请求到 `https://stage1st.com` 并处理 CORS 头。

## 架构说明

### API 对接

S1 Client 对接 Discuz! 的移动端 API（`/api/mobile/index.php`），通过 `module` 参数区分接口类型：

| Module | 用途 |
|--------|------|
| `forumindex` | 版块列表与用户资料 |
| `forumdisplay` | 版块内主题列表 |
| `viewthread` | 帖子详情 |
| `login` | 用户登录 |
| `sendpost` | 发送回复 |

### Formhash 机制

Discuz! 使用 formhash 进行 CSRF 防护。`S1HttpClient` 在请求拦截器中自动从响应中提取 formhash，并在后续 POST/PUT 请求中自动注入到 URL query 和 body 中。

### 登录流程

**原生平台（Android/iOS/Desktop）**：通过 WebView 加载 Discuz! 登录页 → 用户手动输入凭据 → WebView 注入 CSS 简化页面 → 扫描 Cookie → 检测到 auth Cookie 后同步到本地 Cookie Jar → 完成登录。

**Web 平台**：通过 API 方式登录（输入用户名密码 → 获取 formhash → POST 登录请求 → 验证响应）。

### 速率限制

`S1HttpClient` 内置了每秒最多 2 个请求的速率限制，避免对 S1 服务器造成压力。

## 开发脚本

| 脚本 | 用途 |
|------|------|
| `scripts/proxy_server.dart` | Web 开发 CORS 代理服务器 |
| `scripts/start_dev.ps1` | 一键启动代理 + Flutter Web 开发环境 |
| `scripts/watch_proxy.ps1` | 文件监听 + 代理模式 |
| `scripts/download_emoticons.dart` | 从 GitHub 下载 S1 论坛表情包 |
| `scripts/test_api.dart` | API 接口测试 |
| `scripts/test_post.dart` | 发帖功能测试 |

## 关于 Stage1st

[Stage1st](https://stage1st.com)（简称 S1）是国内知名的 ACG 综合论坛，创立于 2002 年，以游戏、动漫、影视、科技等话题讨论著称。本客户端为非官方第三方实现，通过 Discuz! 移动端 API 进行数据交互。
