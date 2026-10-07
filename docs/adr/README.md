# 架构决策记录（ADR）

本目录存放本项目的架构决策记录，采用轻量（Nygard 风格）格式：每条决策一个文件，编号递增，`0001-` 起。

## 何时新增一条

- 做出一个"将来探索者会重复提出"的架构决策时。
- 否决某个方案、且否决理由将来仍有参考价值时（记录为"备选方案"）。
- 决策与既有 ADR 冲突时，不要静默覆盖：新开一条并显式引用旧条。

被否决的**短暂理由**（"现在不值得做"）或**不言自明**的理由不必记录。

## 文件结构

```
docs/adr/
├── README.md                       ← 本文件
├── 0001-parser-transport-seam.md
└── 0002-....md
```

每个文件包含：标题、状态（提议 / 已接受 / 已取代 / 已废弃）、日期、相关链接、背景、决策、结果、备选方案。

## 状态

- **提议**：已记录，尚未采纳。
- **已接受**：当前生效。
- **已取代**：被更新的 ADR 覆盖（在标题处写明取代它的编号）。
- **已废弃**：不再适用，但保留供追溯。

## 索引

| 编号 | 标题 | 状态 |
|:---|:---|:---|
| [0001](0001-parser-transport-seam.md) | 解析（纯）与传输（I/O）分层：抽出 DiscuzParser | 已接受 |
| [0002](0002-draft-codec.md) | 草稿编解码：三域收敛到 MapDraftCodec，私信独立 | 已接受 |
| [0003](0003-post-body-cache.md) | 帖子正文解析缓存收敛到 PostBodyCache | 已接受 |
| [0004](0004-http-event-seam.md) | HTTP 客户端通知依赖反转：事件出、适配器落库 | 已接受 |
| [0005](0005-share-encoder.md) | 分享卡编码独立为 ShareEncoder | 已接受 |
| [0006](0006-quote-patterns.md) | 引语语法集中到 QuotePatterns；完整 QuoteBlock 合并暂缓 | 已接受 |
| [0007](0007-reading-progress-tracker.md) | 阅读进度状态抽出为 ReadingProgressTracker；完整 ThreadOpenCoordinator 暂缓 | 已接受 |
| [0008](0008-keep-thin-notifiers.md) | forumListProvider 与 postShareProvider 保留（不删） | 已接受 |
