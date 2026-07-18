# S1er 安全审计报告（2026-07-18）

## 0. 范围与红线

| 项 | 说明 |
|:---|:---|
| **审计对象** | 本仓库第三方开源客户端 S1er（`lib/`、`scripts/`、平台配置、备份格式、构建脚本、依赖） |
| **非对象** | `stage1st.com`、Discuz 后端、CDN、图床等**他人资产** |
| **方法** | 静态代码审查 + 既有单测覆盖核对；**未**对外部主机做渗透、扫描、爆破或 SSRF 实测 |
| **复现方式** | 本地路径引用、纯逻辑用例、既有 `flutter test` 目标；不写对外攻击 PoC |
| **影响面表述** | 对本应用用户 / 本机开发者；不写成「攻破论坛」 |

**红线回顾**：S1er 仅为第三方客户端。禁止把论坛或第三方服务器当靶场。

---

## 1. 威胁模型摘要

```text
[用户设备]
  Native: AES-GCM 加密 Cookie 文件 + FlutterSecureStorage 密钥
  Web:    浏览器 Cookie + 本地 CORS 代理内存 Cookie jar
  Drift:  明文 SQLite（设置/草稿/历史/黑名单/投票）
  备份:   未加密 L1 ZIP（白名单字段，不含 Cookie）

[本机开发代理 localhost:19080]  ← 仅开发 Web
  转发论坛 API；可选 /img-proxy、/ext-upload
  默认 PROXY_AUTH_TOKEN 为空 → 鉴权关闭

[外部（他人）]
  stage1st.com / 图床 / 升级清单宿主 — 本审计不探测
```

信任边界重点：

1. **会话秘密**：论坛 Cookie、formhash（内存）、Cookie 加密密钥。
2. **本地隐私**：草稿、阅读历史、黑名单、设备机型小尾巴。
3. **开发代理**：同机其他进程滥用 localhost 代理与会话。
4. **内容驱动**：恶意帖子 BBCode → 外链 scheme / 属性注入 / 图片 URL。

---

## 2. 已核实的安全控件（OK）

| 控件 | 证据 |
|:---|:---|
| 密码不落盘 | 仅登录 UI controller → POST；无 Drift / SecureStorage 密码写入 |
| Native Cookie AES-256-GCM | [`encrypted_cookie_storage.dart`](../lib/services/encrypted_cookie_storage.dart) + `PersistCookieJar` |
| Cookie / 草稿不进 L1 备份 | [`s1_backup_codec.dart`](../lib/services/backup/s1_backup_codec.dart) `appToBackup` 白名单；[`backup-format-v1.md`](backup-format-v1.md) |
| Native 登出清 Cookie | [`auth_service.dart`](../lib/services/auth_service.dart) `cookieJar.deleteAll()` |
| formhash 仅内存 + 写操作注入 | [`http_client.dart`](../lib/services/http_client.dart) / [`formhash_service.dart`](../lib/services/formhash_service.dart) |
| 主 Dio 超时 + 2 req/s 限速 | [`http_client.dart`](../lib/services/http_client.dart)、[`constants.dart`](../lib/config/constants.dart) |
| 代理绑定 `localhost` | [`proxy_server.dart`](../scripts/proxy_server.dart) `HttpServer.bind('localhost', …)` |
| CORS Origin 限 `http://localhost(:port)?` | 同上 `_localhostOrigin` |
| 严格白名单 `isAllowedProxyTarget` | [`resource_domains.dart`](../lib/config/resource_domains.dart)（authImage / publicAsset） |
| Android `allowBackup="false"` | [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) |
| iOS 无 ATS 任意放行 | [`Info.plist`](../ios/Runner/Info.plist) |
| 无 `HttpOverrides` / 信任全证 | `lib/` 未找到绕过 TLS 校验 |
| Talker 默认不打印请求/响应体与 Header | [`main.dart`](../lib/main.dart) |
| `EnvConfig.sentryDsn` 默认空 | [`env_config.dart`](../lib/config/env_config.dart) |
| CI workflow 无硬编码凭据 | [`.github/workflows/deploy-site.yml`](../.github/workflows/deploy-site.yml) |
| 图片锚点 `javascript:` 过滤 | [`post_image_urls.dart`](../lib/utils/post_image_urls.dart) + 既有测试 |
| `lib/` 未使用 WebView | `webview_flutter` 仅在 `pubspec.yaml`，无业务引用 |

---

## 3. 发现列表

### 3.1 High

#### H-1 — Web 登出在默认配置下不清理代理会话

| 字段 | 内容 |
|:---|:---|
| **影响** | 本机 Web 开发者：UI 显示已退出，代理内存 jar 仍可能附带论坛 Cookie；刷新/`checkSession` 可恢复登录态 |
| **证据** | [`auth_service.dart`](../lib/services/auth_service.dart)：仅当 `kIsWeb && EnvConfig.proxyAuthToken.isNotEmpty` 才 POST `/proxy/session/clear`；`PROXY_AUTH_TOKEN` 默认 `''`（[`env_config.dart`](../lib/config/env_config.dart)） |
| **本地复现** | 读代码路径即可确认条件分支；不要求对论坛反复登录验证 |
| **建议** | Web 登出始终请求 `/proxy/session/clear`（无 token 时亦然，或代理提供无鉴权本地 clear）；并清理 `formhashProvider` |

#### H-2 — 本地 `/img-proxy` allowlist 过宽（任意 HTTPS）

| 字段 | 内容 |
|:---|:---|
| **影响** | 本机开发者：任意能访问 `localhost:19080` 的进程，可把代理当开放 HTTPS 转发器使用（默认无 `PROXY_AUTH_TOKEN`）。论坛 Cookie **不会**附到非 authImage 主机（缓解）。 |
| **证据** | [`resource_domains.dart`](../lib/config/resource_domains.dart) `isAllowedImgProxyTarget`：通过严格白名单后，对其余 HTTPS 仅拦 http / userInfo / IPv4 字面量 / localhost / 非 443，然后 `return true`。注释写「仅 https + 白名单」与实现不符。 |
| **纯逻辑用例（无网络）** | 见 §4 |
| **建议** | 收紧为显式图床/CDN 主机列表；拒绝 host 含 `:`（IPv6）；代理上游 `followRedirects = false` 或逐跳再校验 |

#### H-3 — 正文外链无 scheme 白名单即 `launchUrl`

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：恶意帖可诱导点击打开 `javascript:` / `intent://` / `file:` 等非 http(s) URI（系统处理，非浏览器 XSS） |
| **证据** | [`post_link_resolver.dart`](../lib/utils/post_link_resolver.dart)：非论坛 host → `ExternalPostLink`；[`bbcode_renderer.dart`](../lib/widgets/bbcode_renderer.dart) `launchUrl(..., externalApplication)` 无 scheme 过滤 |
| **本地复现** | 单测断言：`PostLinkResolver.resolve('javascript:alert(1)')` / `intent://…` / `file:///…` 应为 `InvalidPostLink`（当前预期为 `ExternalPostLink`） |
| **建议** | 仅允许 `http`/`https`（可选 `mailto`）；其余 `InvalidPostLink` |

---

### 3.2 Medium

#### M-1 — 构建/开发脚本硬编码 Sentry DSN

| 字段 | 内容 |
|:---|:---|
| **影响** | 用 `scripts/build.ps1` / `start_dev.ps1` 构建时默认启用崩溃上报；DSN 进 Git；与 [`privacy-policy.md`](privacy-policy.md)「默认不启用、仅用户显式注入」及 [`sentry-setup.md`](sentry-setup.md) 指导不一致 |
| **证据** | [`scripts/build.ps1`](../scripts/build.ps1) L5–13；[`scripts/start_dev.ps1`](../scripts/start_dev.ps1) 同类回退 |
| **建议** | 删除硬编码；仅读 `S1_SENTRY_DSN`；空则不注入；在 Sentry 控制台轮换已暴露 DSN |

#### M-2 — Talker 错误路径可能记录 Header/Body

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：失败响应的 Header/Body（含 `Set-Cookie` 等）可能进设备内 Talker 历史（关于页连点可进） |
| **证据** | [`main.dart`](../lib/main.dart)：关闭了 request/response data/headers，未覆盖 `printErrorData` / `printErrorHeaders`（包默认多为 true） |
| **建议** | 显式 `printErrorData: false`、`printErrorHeaders: false`；可加 `hiddenHeaders`；生产构建隐藏 TalkerScreen |

#### M-3 — BBCode URL/颜色属性未转义

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：属性断裂 / 异常 markup；`flutter_html` 一般不执行脚本，故非经典 XSS，但仍有注入与样式滥用面 |
| **证据** | [`bbcode_parser.dart`](../lib/utils/bbcode_parser.dart)：`[url=…]` / `[color=…]` 直接插值；`_preClean` 先解码实体 |
| **本地用例** | `[url=https://a.com" data-x="1]t[/url]` → 属性断裂；`[color=red;background-image:url(https://t.example/p)]x[/color]` → 扩展 style |
| **建议** | 属性值 HTML 转义；颜色限 `#hex`/具名色 |

#### M-4 — 备份 ZIP 导入无大小/膨胀限制

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：选择恶意 ZIP 可能导致 OOM/卡死（本地 DoS，需用户主动导入） |
| **证据** | [`s1_backup_io.dart`](../lib/services/backup/s1_backup_io.dart) 整文件读入；[`s1_backup_codec.dart`](../lib/services/backup/s1_backup_codec.dart) `ZipDecoder().decodeBytes` 无上限 |
| **建议** | 限制压缩包、解压后总量、条目数、单文件大小 |

#### M-5 — 图床返回 URL 未校验主机

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：异常/被篡改的上传响应可把任意 URL 写入 `[img]` |
| **证据** | [`external_image_upload_service.dart`](../lib/services/external_image_upload_service.dart) 直接返回 `data.url` |
| **建议** | 校验 `https` + host `p.sda1.dev`（及路径规则） |

#### M-6 — 升级清单渠道 URL 无主机白名单

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：清单宿主被篡改或 MITM（自定义 CA）时，更新 CTA 可指向恶意下载页（无 APK 签名校验） |
| **证据** | [`update_check_service.dart`](../lib/services/update_check_service.dart) `resolveDownloadUrl` 信任 JSON 字段 |
| **建议** | 白名单 GitHub Releases / Play 等预期主机；文档化信任模型 |

#### M-7 — Drift 明文存储草稿等敏感本地数据

| 字段 | 内容 |
|:---|:---|
| **影响** | App 用户：root / 磁盘镜像可读草稿、历史、黑名单（Cookie 另有加密，且 Android 禁系统备份） |
| **证据** | [`app_database.dart`](../lib/services/app_database.dart)；草稿 key：`compose_message_drafts` 等 |
| **建议** | 文档披露残余风险；可选加密敏感 settings；登出时清草稿（产品决策） |

#### M-8 — 隐私文案与 `device_info_plus` / 脚本默认 Sentry 不一致

| 字段 | 内容 |
|:---|:---|
| **影响** | 合规/信任：政策称「不收集设备型号」且 Sentry 默认关；实际小尾巴可把机型写入发帖签名（发往论坛，非开发者），脚本构建默开 Sentry |
| **证据** | [`device_model_label.dart`](../lib/services/device_model_label.dart)；[`privacy-policy.md`](privacy-policy.md) §1.1 / §2.1 |
| **建议** | 对齐文案与默认值；设置页说明「仅本地读取，可选写入帖子签名」 |

#### M-9 — Web 无 CSP

| 字段 | 内容 |
|:---|:---|
| **影响** | Web 部署缺少纵深防御；当前无经典 DOM XSS 引擎面，但未来注入路径更脆 |
| **证据** | [`web/index.html`](../web/index.html) 无 CSP meta |
| **建议** | 部署时加 CSP（需兼容 Flutter bootstrap / wasm / 代理） |

#### M-10 — 代理默认无鉴权 + 内存会话 jar

| 字段 | 内容 |
|:---|:---|
| **影响** | 本机开发者：同机进程可复用已登录代理会话调用论坛 API 路径（绑定仍限 localhost） |
| **证据** | [`proxy_server.dart`](../scripts/proxy_server.dart) `_verifyAuthToken` 在 token 空时直接 true；进程级 `_cookieJar` |
| **建议** | README 强化警示；开发默认生成并打印 token，客户端同步 `--dart-define`；或文档要求共享机必设 token |

---

### 3.3 Low

| ID | 标题 | 建议 |
|:---|:---|:---|
| L-1 | 登出不清理内存 formhash | `logout()` 调用 `formhashProvider` clear |
| L-2 | `FlutterSecureStorage()` 未显式平台 options | 固定 Android/iOS Keystore/Keychain 选项并文档化 |
| L-3 | `webview_flutter` 未使用仍进依赖 | 移除直至需要；再引入时禁用 JS + 导航白名单 |
| L-4 | `/ext-upload` 代理侧无 body 上限 | 与客户端 5MB 对齐在代理截断 |
| L-5 | CI 无依赖漏洞扫描 | 增加 `dart pub outdated` / 可用时的 `dart pub audit` 或 OSV |
| L-6 | 图片 `src` 未强制 http(s) | 与锚点过滤对齐 |

---

### 3.4 Info

| ID | 标题 | 说明 |
|:---|:---|:---|
| I-1 | 无证书 pinning | 系统信任即可接受；企业 MITM 可见流量 |
| I-2 | Cookie 解密失败静默 `null` | fail-closed；可打无敏感信息的日志 |
| I-3 | 代理 stdout 打 Cookie 名与 URL | 本地开发可接受；URL 可能含 formhash |
| I-4 | `checkSession` 裸 `catch` | 可观测性，非凭据泄漏 |
| I-5 | 代理上游默认跟随重定向 | 与 H-2 叠加；`rewriteProxyLocation` 仅改写同 host Location |

---

## 4. `/img-proxy` 纯逻辑用例（无网络）

基于 [`isAllowedImgProxyTarget`](../lib/config/resource_domains.dart) / [`isAllowedProxyTarget`](../lib/config/resource_domains.dart)：

| URL | `isAllowedProxyTarget` | `isAllowedImgProxyTarget` |
|:---|:---|:---|
| `https://img.stage1st.com/a.jpg` | pass | pass |
| `https://static.stage1st.com/x.gif` | pass | pass |
| `https://evil.example/x.png` | fail | **pass** |
| `https://p.sda1.dev/3/t.png` | fail | **pass** |
| `https://stage1st.com/2b/api` | fail | **pass** |
| `http://img.stage1st.com/a.jpg` | fail | fail |
| `https://127.0.0.1/secret` | fail | fail |
| `https://localhost/x` | fail | fail |
| `https://user@img.stage1st.com/a` | fail | fail |
| `https://img.stage1st.com:8443/a` | fail | fail |
| `https://[::1]/secret`（host 含 `:`） | fail（`:`） | **pass**（img 路径未拒 `:`） |

既有测试（[`resource_domains_test.dart`](../test/config/resource_domains_test.dart)）覆盖白名单与 `http`/`localhost` 拒绝，**未**覆盖「任意 HTTPS 主机放行」与 IPv6。

---

## 5. 禁止清单抽检

| 禁止项 | 结果 |
|:---|:---|
| 硬编码用户密码 / API Key | 未发现（论坛 API 为公开地址） |
| Cookie 进 Drift / L1 备份 | 未发现 |
| 绕过 `S1HttpClient` 的论坛主路径 | 上传与升级检查使用独立 Dio（有意例外，已记录） |
| `HttpOverrides` 信任坏证 | 未发现 |
| 仓库 `.env` / 测试账号 | 未发现；**有**脚本硬编码 Sentry DSN（M-1） |

---

## 6. 修复优先级队列（本期不改代码）

建议按序开修复 PR（影响面均为本应用/本机）：

1. **H-3** 外链 scheme 白名单 + 单测  
2. **H-1** Web 登出始终清代理会话 + 清 formhash  
3. **H-2** 收紧 `isAllowedImgProxyTarget` + 代理禁用自动重定向 + 补单测  
4. **M-1** 移除脚本硬编码 DSN 并轮换  
5. **M-2** Talker error 日志收紧  
6. **M-3 / M-5** BBCode 属性转义 + 图床 URL 校验  
7. **M-4** 备份导入资源上限  
8. **M-6 / M-8 / M-9** 升级 URL 白名单、隐私文案、Web CSP  
9. **L-*** 依赖清理、secure storage options、CI audit  

回归测试建议（本地）：

- `PostLinkResolver`：危险 scheme → `InvalidPostLink`  
- `isAllowedImgProxyTarget`：拒绝未知主机 / IPv6；仅允许显式列表  
- L1 导出 ZIP：断言不含 draft keys / cookie 字段  
- 备份 decode：超限 ZIP 失败  

---

## 7. 残余风险（接受或文档化）

- 系统 TLS 信任、无 pinning（第三方客户端常见选择）。  
- Drift / 备份 ZIP 明文：设备物理妥协或用户主动分享备份时可见历史与黑名单。  
- Web 会话依赖浏览器 Cookie + 本地代理模型，安全边界弱于 Native 加密 jar。  
- 帖子外链图片本身会发起网络请求（产品功能）；收紧的是代理转发与危险 scheme，而非禁止外链图。  
- 本审计未运行完整 `flutter test` / `dart pub audit`（执行环境 Flutter SDK 当时不可用）；结论以静态证据为准，修复 PR 中应补跑测试。

---

## 8. 结论

未发现「密码明文持久化」或「Cookie 进入备份」类 Critical 缺陷。最高优先级为：**本机 Web 代理会话清理与 `/img-proxy` 过宽转发**，以及 **正文外链 scheme 校验**——均影响本应用用户或本机开发者，**不构成对论坛服务器的攻击面评估**。

本期交付仅为审计报告与修复队列；具体代码修复待确认后另开 PR。
