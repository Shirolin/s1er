# 术语表（GLOSSARY）

本项目的领域语言。工程 skill（issue 标题、重构提案、测试命名等）应使用这里的措辞，不要漂移到表格中"避免"的同义词。

> 本文件按需生长：术语在讨论中真正澄清时才加入。尚未列入的，不代表项目不采用。

## 架构

| 术语 | 含义 | 避免 |
|:---|:---|:---|
| **模块（module）** | 有接口与实现的任何东西；刻意不限定粒度（函数 / 类 / 包 / 跨层切片）。 | 组件、服务、单元 |
| **接口（interface）** | 调用方为正确使用模块所需知道的一切：类型签名，以及不变量、次序约束、错误模式、必需配置、性能特征。 | API、signature |
| **接缝（seam）** | 可以在不就地编辑的情况下改变行为的位置；模块接口所在之处。 | 边界（boundary）、分层（layer） |
| **适配器（adapter）** | 在接缝处满足接口的具体物；描述角色而非内容。 | — |
| **深度（depth）** | 接口处的杠杆：调用方（或测试）每学一单位接口能驱动的行为量。 | — |
| **局部性（locality）** | 维护者从深度获得的收益：变更、bug、知识与验证集中在一处。 | — |

## 本项目概念

| 术语 | 含义 | 备注 |
|:---|:---|:---|
| **DiscuzParser** | 承载全部纯解析逻辑（JSON 解析与 HTML 抓取）的模块，返回模型/数据。 | 不引入 Flutter 依赖；见 [ADR-0001](adr/0001-parser-transport-seam.md) |
| **解析（parsing）** | 把服务端响应（JSON / HTML / XML）转换为 `models/*` 中数据模型的过程。 | 纯函数；与传输分离 |
| **传输（transport）** | HTTP 请求/响应的发送接收、限速、Cookie/formhash、URL 构造与协议判定。 | 归 `ApiService` / `S1HttpClient`；见 [ADR-0001](adr/0001-parser-transport-seam.md) |
| **草稿（draft）** | 撰写中的回复 / 新主题 / 编辑 / 私信正文，按域存于 `SettingsStore`，永不写服务端。 | 键空间按域互斥；见 [ADR-0002](adr/0002-draft-codec.md) |
| **MapDraftCodec** | 草稿 map 的通用编解码（`entryKey → payload map` 的 parse / upsert / remove / toStoreValue）。 | 服务回复/新主题/编辑三域；私信形状不同不并入 |
| **PostBodyCache** | 帖子正文 BBCode→HTML 的解析结果缓存策略：拥有「什么构成等价解析」的键规则与命中/未命中来源。 | 不依赖 Flutter/Riverpod；见 [ADR-0003](adr/0003-post-body-cache.md) |
| **HTTP 事件（S1HttpEvent）** | `S1HttpClient` 从响应/错误体观测到、需向上通知的事件（未读计数、服务器公告）。 | 客户端只发事件；provider 层适配器落库；见 [ADR-0004](adr/0004-http-event-seam.md) |
| **ShareEncoder** | 分享卡编码：按格式分派 PNG/JPEG/WebP 并在 native 失败时降级回 PNG；背景色由调用方解析。 | 不依赖 widget/Theme/Riverpod；见 [ADR-0005](adr/0005-share-encoder.md) |
| **QuotePatterns** | 引语 BBCode / HTML 结构模式的单一出处（含严格 vs 宽松头等**有意区分**的变体）。 | 见 [ADR-0006](adr/0006-quote-patterns.md) |
| **ReadingProgressTracker** | 帖子详情页会话内的阅读进度状态（首写/上次页与页内楼/页内记忆）与写回策略（去重、高水位下界）。 | 纯 Dart；render-bound 滚动胶水不入此模块；见 [ADR-0007](adr/0007-reading-progress-tracker.md) |
| **承重透传 provider** | implementation 薄、但接口承载分层规则 / 失效 / 刷新 / 测试注入的 provider（如 `postShareProvider`、`forumListProvider`）。 | 禁止以「interface ≈ implementation」为由删除；见 [ADR-0008](adr/0008-keep-thin-notifiers.md) |
