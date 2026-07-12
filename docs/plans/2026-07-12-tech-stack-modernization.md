# 技术栈现代化方案（定稿）

> 版本：v1.0 | 日期：2026-07-12  
> 状态：**已定案，待实施**（基于 `main` @ `faf435d` 讨论）  
> 相关：`docs/backup-format-v1.md`（跨客户端备份格式）  
> 实施后须同步更新 `AGENTS.md` 技术栈锁定与「当前已知约束」

---

## 1. 背景与目标

本项目为新应用，不希望以停更或明显过时的依赖作为长期底座。经依赖审计与讨论，确定：

| 目标 | 说明 |
|:---|:---|
| 性能优先 | 本地结构化数据用 SQLite（Drift）；可接受底层重建 |
| 架构可演进 | 多表（设置、阅读历史、黑名单等）、事务、索引 |
| 跨客户端可迁移 | 开放备份格式（JSON ZIP），第三方可集成 |
| 省流量 | 图片磁盘缓存 + 用户可清理 |
| 文档同步 | 实现与 `AGENTS.md` / 备份规范一并更新 |

**不做**：为省几 KB 继续绑 Hive；把私有 `.db` 当作跨客户端标准；把图片缓存打进备份包。

---

## 2. 目标依赖一览

| 层级 | 现状（pubspec） | 目标 | 决策 |
|:---|:---|:---|:---|
| 状态管理 | `flutter_riverpod: ^2.5.0` | `^3.x`（如 3.3.x） | **全量**迁 `Notifier` / `AsyncNotifier`，不长期用 `legacy.dart` |
| 路由 | `go_router: ^14.0.0` | `^17.x` | 同里程碑或紧随；路由主要在 `lib/app.dart` |
| 本地结构化存储 | `hive` / `hive_flutter` | **Drift + SQLite** | 替换 Hive；见 §3 |
| 代码生成 | `hive_generator` + `build_runner` | **仅服务 Drift** | 删除 hive_generator；build_runner 为 Drift 保留 |
| HTML | `flutter_html: ^3.0.0-beta.2` | `^3.0.0` | lock 已解析到稳定 3.0.0，改约束即可 |
| Lint | `flutter_lints: ^4.0.0` | `^6.0.0` | 单独消化新规则 |
| 图片缓存 | 无磁盘方案 | `flutter_cache_manager`（或等价）+ 统一组件 | 见 §5 |
| 其余 | dio / talker / secure_storage / … | 保持主版本，仅补丁升级 | 多数已最新 |

审计时仍可通过 `flutter pub outdated` 复核；上表为产品决策，不以「全部追 latest」为准则。

---

## 3. 本地存储：Hive → Drift

### 3.1 为何选 Drift（而非 Sembast / prefs+JSON / Isar）

| 方案 | 结论 |
|:---|:---|
| A Sembast | 低摩擦换 Hive，够用；但索引/事务/多表弱于 SQLite |
| B prefs + JSON | 设置合适；历史/黑名单/备份自研成本高，不适合主引擎 |
| C1 Isar 社区版 | 性能好，官方停更靠 fork，新项目核心存储风险更大 |
| **C2 Drift / SQLite** | **选定**：性能上限、多表、事务、备份友好、生态稳 |

在「每用户 ≤500 条历史」量级，A 与 C 用户体感差异小；选 Drift 是为了**架构 + 性能上限 + 黑名单等多实体 + 备份**，不是因为当前 Hive 已明显卡顿。

磁盘占用：SQLite 相对 Hive **略增**（页/索引/可能的 WAL），本项目通常为 KB～百 KB 级，可忽略。

### 3.2 目标架构

```
UI / Providers
    ↓
Repository（services/ 或 repositories/，遵守单向数据流）
    ↓
Drift (SQLite)  ← 唯一结构化真相源
    ↓
可选：settings / 当前帖进度的小内存投影（同步感）

Cookie → 继续 PersistCookieJar（废弃 Hive `cookies` 死 box）
图片  → 独立磁盘缓存（§5），不进 DB、不进备份
```

### 3.3 表结构草图

| 表 | 用途 | 要点 |
|:---|:---|:---|
| `app_settings` | 主题、字号等 | KV 或单行；实施时二选一，推荐 **KV** 便于扩展 |
| `reading_history` | 阅读进度/历史 | 唯一 `(uid, tid)`；索引 `(uid, last_read_at)`；沿用现有字段语义 |
| `blacklist` | 黑名单（规划） | `uid` / username、时间、scope 等 |
| `poll_votes` | 本地投票选择缓存 | `(uid, tid)` + 选项列表 |

迁移：从 Hive Box 读出后写入 Drift，一次升级路径；无 Hive 数据则空库启动。Web：Drift + sqlite3 wasm，里程碑内显式验收。

### 3.4 删除

- `hive`、`hive_flutter`、`hive_generator`
- `main.dart` 中 `Hive.initFlutter` / `openBox`
- 未使用的 `cookies` box

---

## 4. Riverpod 3

### 4.1 策略：彻底迁移（非渐进 legacy）

现状大量 `StateNotifierProvider` / `StateProvider`。Riverpod 3 将其移至 `legacy.dart`。

**定案**：升到 3.x 时直接改为 `Notifier` / `AsyncNotifier` / `NotifierProvider` 等，测试中的 `overrideWith` 一并改。

### 4.2 影响面（实施时核对）

- `lib/providers/*`（auth、settings、post、thread_list、reading_history、pm/notice、user_space、messages_segment 等）
- 依赖上述 provider 的 screens / widgets / tests
- `AsyncValue.valueOrNull` → `.value`（Riverpod 3 breaking）

---

## 5. 图片磁盘缓存

### 5.1 现状问题

- Dio 拉取的图：仅**内存 LRU**（约 200 条 / 50MB），进程结束即失效
- 公开资源：`NetworkImage` / `<img>`，无 App 级可管理磁盘库
- 无「清除图片缓存」；同图反复进入易重复下载，费流量

### 5.2 定案

| 项 | 决定 |
|:---|:---|
| Native | 统一磁盘缓存（推荐 `flutter_cache_manager` + 统一 Image 组件）；需 Cookie/代理的图下载后写入同一缓存 |
| Web | 不强求与 Native 同等磁盘策略；可继续依赖浏览器缓存 |
| 设置 | 「清除图片缓存」；可选展示占用大小 |
| 上限 | 配置 max 对象数、过期天数、体积策略（实施时定具体数字） |
| 备份 | **禁止**进入 `s1-backup` |

---

## 6. 备份与跨客户端格式

详见 **`docs/backup-format-v1.md`**。摘要：

| 层 | 内容 | 默认导出 |
|:---|:---|:---|
| L1 互通层 | `*.s1backup.zip`（manifest + JSON 数组） | **是**（导出/网盘/第三方） |
| L2 原生层 | `native/s1_app.db` | 否（高级选项，本 App 快速恢复） |

原则：**跨客户端只保证 L1**；运行时用 Drift，交换格式用开放 JSON。

---

## 7. 其他依赖与文档

| 项 | 动作 |
|:---|:---|
| `flutter_html` | 约束改为 `^3.0.0` |
| `webview_flutter` 等 | `flutter pub upgrade` 吃补丁 |
| `go_router` 17 | 对照 CHANGELOG 改 `app.dart` 等 |
| `flutter_lints` 6 | 升后修 analyze |
| `AGENTS.md` | 技术栈表改为 Riverpod 3 / Drift / go_router 17 等；去掉 Hive 停更表述；flutter_html 不再写 beta |

---

## 8. 实施阶段

| 阶段 | 内容 | 风险 |
|:---|:---|:---|
| **0** | `flutter_html` 约束 + 安全补丁升级 | 低 |
| **1** | Hive → Drift；Repository；表结构（含 blacklist 预留）；删 hive_* | 高 |
| **2** | Riverpod 3 全量迁移 + 测试改造 | 高 |
| **3** | 图片磁盘缓存 + 设置清理 | 中 |
| **4** | 备份 L1（+ 可选 L2）+ 保证与 `backup-format-v1.md` 一致 | 中 |
| **5** | go_router 17 + flutter_lints 6 | 中 |
| **6** | 更新 `AGENTS.md` | 文档 |

建议 **1 与 2 不要和无关键大改混在同一 PR**；0 可并入 1。阶段可拆多 PR，但须保持主干可测。

### Definition of Done（本现代化）

- `flutter analyze` 无 error/warning  
- `flutter test` 通过；核心存储/备份/缓存有测试  
- M3 审计无 CRITICAL  
- Web + 至少一移动/桌面路径验证：登录会话、读帖、图片二次打开不重复狂下（Native）、备份导出导入  
- `AGENTS.md` 与备份文档已更新  

---

## 9. 明确不做

1. 继续以 Hive 为长期本地库  
2. 以私有 SQLite 文件作为第三方互通标准  
3. 备份包包含 Cookie、密码、图片缓存  
4. Riverpod 3 长期停留在 `legacy.dart`  
5. 为「全部依赖 latest」而无目的大版本乱升  

---

## 10. 决策记录

| 日期 | 决策 |
|:---|:---|
| 2026-07-12 | 本地存储选 Drift；Riverpod 全量 3.x；备份 L1 JSON ZIP 默认、L2 DB 可选；图片磁盘缓存；列表 JSON 数组；导入同键覆盖 |
| 2026-07-12 | 基线主干 `faf435d`；本方案文档落入仓库后再开实施 |
