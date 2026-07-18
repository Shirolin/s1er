# S1er 安全审计摘要（2026-07-18）

> 完整发现列表与复现细节已从公开树移除。本文仅保留范围、结论与仍接受的残余风险，供用户与贡献者参考。

## 范围

| 项 | 说明 |
|:---|:---|
| **对象** | 本仓库第三方客户端（`lib/`、`scripts/`、平台配置、备份、构建脚本、依赖） |
| **非对象** | `stage1st.com`、Discuz 后端、CDN、图床等他人资产 |
| **方法** | 静态代码审查 + 既有单测核对；未对外部主机做渗透或扫描 |

S1er 仅为第三方客户端。禁止把论坛或第三方服务器当靶场。

## 结论

未发现「密码明文持久化」或「Cookie 进入备份」类 Critical 问题。

2026-07-18 审计中的 **High** 与多数 **Medium** 项已在同日修复 PR 中落地，包括（摘要）：

- Web 登出时清理本地开发代理会话与内存 formhash
- 收紧本地图片代理允许名单，并限制危险外链 scheme
- 移除构建脚本中的硬编码 Sentry DSN（仅环境变量显式注入）
- Talker 错误日志不再打印 Header/Body
- BBCode 属性消毒、图床返回 URL 校验、备份 ZIP 导入资源上限
- 升级清单下载 URL 主机白名单；隐私文案与机型小尾巴说明对齐

## 已核实的安全基线（仍成立）

- 用户密码不落盘；Native Cookie 经 AES-GCM 加密存储
- Cookie / 草稿不进入 L1 备份；Android `allowBackup="false"`
- 主路径 HTTP 经 `S1HttpClient`（超时 + 限速）；无全局信任坏证
- 开发代理默认绑定 `localhost`；Sentry 默认关闭，需显式 `--dart-define`

## 仍开放 / 接受的残余风险

| 项 | 说明 |
|:---|:---|
| Drift 明文 | 设置、草稿、阅读历史、黑名单等存本地 SQLite；设备被物理妥协时可读（Cookie 另有加密） |
| 备份 ZIP 明文 | 用户主动导出的 L1 包不含 Cookie，但含历史/黑名单等；分享前需自知 |
| Web 开发代理 | 本机 `localhost` 代理为开发便利；共享机器请设 `PROXY_AUTH_TOKEN`（见 README） |
| 无证书 pinning | 依赖系统 TLS 信任；企业 MITM 环境下流量可见 |
| Web CSP | 生产 Web 部署尚未强制 CSP（纵深防御，后续可选） |
| 未使用的 `webview_flutter` 依赖 | 业务未引用；后续可移除 |

## 报告安全问题

请勿在公开 Issue 中粘贴真实 Cookie、密码或完整会话抓包。可通过仓库 Issue（可标 private / security）或维护者公开联系渠道私下说明影响面与复现步骤。
