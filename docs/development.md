# 开发指南

本地运行、Web 代理、编译期配置与常用脚本。贡献流程见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

## 环境

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.4`
- Dart SDK `>=3.4 <4.0`（随 Flutter 提供）
- Git
- Android：Android SDK 与 JDK 17
- iOS / macOS：macOS 与对应版本的 Xcode

```bash
git clone https://github.com/Shirolin/s1er.git
cd s1er
flutter doctor
flutter pub get
```

克隆后即可构建；麻将脸资源已入库于 `assets/emoticons/`，无需单独下载。

## 原生平台

```bash
flutter devices
flutter run -d <device-id>
```

原生端登录 Cookie 通过 `PersistCookieJar` 持久化，落盘内容使用 AES-256-GCM 加密，密钥保存在系统安全存储中。

## Web 开发代理

S1 接口不允许浏览器直接跨域访问。请先启动仅监听 `localhost` 的开发代理，再启动 Flutter Web。

Windows 可使用一键脚本：

```powershell
.\scripts\start_dev.ps1
```

也可以分别启动两个进程：

```bash
# 终端 1：CORS / Cookie / 图片与图床代理
dart run scripts/proxy_server.dart

# 终端 2：Flutter Web
flutter run -d chrome
```

无头环境可将第二条命令替换为：

```bash
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

代理默认监听 `http://localhost:19080`，只接受 `localhost` Origin。开发模式下未设置 `PROXY_AUTH_TOKEN` 时不校验 token；如需显式启用，请在代理与 Flutter 编译参数中使用同一值：

```bash
# 终端 1
dart --define=PROXY_AUTH_TOKEN=replace_with_a_random_value run scripts/proxy_server.dart

# 终端 2
flutter run -d chrome --dart-define=PROXY_AUTH_TOKEN=replace_with_a_random_value
```

> [!WARNING]
> 该代理仅用于本地开发：Cookie 保存在进程内存中，进程结束后即丢失。不要将它暴露到公网，也不要把真实账号、密码、Cookie 或 token 提交到仓库。共享机器或非常驻开发环境建议设置 `PROXY_AUTH_TOKEN`；`/img-proxy` 仅转发论坛图域与 `p.sda1.dev`。

## 配置（`--dart-define`）

应用配置通过 `--dart-define` 在编译期注入，定义集中在 `lib/config/env_config.dart`。

| Key | 默认值 | 说明 |
|---|---:|---|
| `TALKER_ENABLED` | `true` | 是否启用 Talker |
| `TALKER_LOG_LEVEL` | `error` | `error` 仅记录错误，`all` 记录全部请求与响应 |
| `TALKER_MAX_HISTORY` | `500` | 日志历史条数上限 |
| `BBCODE_PROFILE` | `false` | 正文 BBCode parse / Html build 耗时打点（滑动卡顿排查） |
| `PROXY_PORT` | `19080` | Web 代理端口；代理与 Flutter 端必须一致 |
| `PROXY_AUTH_TOKEN` | 空 | 非空时启用本地代理 token 校验 |
| `CONNECT_TIMEOUT` | `20` | 连接超时，单位为秒 |
| `RECEIVE_TIMEOUT` | `30` | 响应超时，单位为秒 |
| `SEND_TIMEOUT` | `30` | 发送超时，单位为秒 |
| `IMAGE_UPLOAD_TIMEOUT` | `120` | 外链图床上传超时（Web `/ext-upload` 同步），单位为秒 |
| `UPDATE_MANIFEST_URL` | GitHub raw `docs/release/latest.json` | 应用升级清单 URL（须可公开访问） |
| `DISTRIBUTION` | `github` | 分发渠道：`github` / `play`（影响升级 CTA） |
| `SENTRY_DSN` | 空 | 非空时启用 Sentry；详见 [Sentry 设置](sentry-setup.md) |
| `SENTRY_TRACES_SAMPLE_RATE` | `0` | 性能采样 0–1；默认仅错误 |
| `SENTRY_DEBUG_UPLOAD` | `false` | debug 是否实际上传（防本机刷配额） |

示例：

```bash
flutter run -d chrome \
  --dart-define=TALKER_LOG_LEVEL=all \
  --dart-define=TALKER_MAX_HISTORY=1000
```

如需修改代理端口，代理进程也必须使用相同的编译期定义：

```bash
dart --define=PROXY_PORT=19081 run scripts/proxy_server.dart
flutter run -d chrome --dart-define=PROXY_PORT=19081
```

代理还会读取 `S1_UPSTREAM_PROXY`，并依次兼容常见的 `HTTPS_PROXY`、`HTTP_PROXY` 与 `ALL_PROXY` 进程环境变量。

## 常用脚本

| 脚本 | 用途 |
|---|---|
| `scripts/start_dev.ps1` | 在 Windows 启动本地代理和 Chrome 开发环境 |
| `scripts/proxy_server.dart` | Web 开发用 CORS、Cookie、图片与图床代理 |
| `scripts/watch_proxy.ps1` | 监听代理文件变更并自动重启 |
| `scripts/download_emoticons.dart` | 从 s1emoticon GitHub Release 按 `download_list.txt` 导入；见 `ATTRIBUTION.md` |
| `scripts/audit_m3.dart` | 扫描 Material Design 3 合规问题 |
| `scripts/build.ps1` | Windows 交互式构建菜单；Release 项需要维护者签名配置 |

麻将脸维护：原 png/gif **已入库**于 `assets/emoticons/`（不转 WebP）。包定义见 `packs.json`，下载清单见 `download_list.txt`，来源声明见 [`ATTRIBUTION.md`](../assets/emoticons/ATTRIBUTION.md)。维护脚本从 [kawaiidora/s1emoticon](https://github.com/kawaiidora/s1emoticon) 的 **GitHub Release zip** 按清单导入（该仓当前**无 LICENSE**，仅致谢再分发）；勿进 CI、勿扫论坛 CDN。

## 宣传站

产品介绍页源码在 [`site/`](../site/)，经 GitHub Actions 部署到 GitHub Pages：

- 站点地址：[https://shirolin.github.io/s1er/](https://shirolin.github.io/s1er/)
- 本地预览：在仓库根目录执行 `npx --yes serve site`（或任意静态文件服务器指向 `site/`）

**首次启用**：仓库 Settings → Pages → Build and deployment → Source 选择 **GitHub Actions**。之后推送 `main` 上 `site/**` 的变更（或手动运行 workflow「Deploy site to GitHub Pages」）即可更新站点。

宣传站截图为 `site/assets/screenshots/*.webp`；源图 PNG（含中文文件名）保留在 [`assets/screenshot/`](../assets/screenshot/)。

## 论坛接口探测

对真实论坛接口做手动探测时，请控制频率并优先使用游客只读接口；勿对真实账号循环登录或高频写操作。`S1HttpClient` 内置每秒最多 2 个请求的限速，不要绕过。
