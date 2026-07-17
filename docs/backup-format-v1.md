# S1 Backup Format v1

> 开放备份 / 迁移格式。第三方客户端可实现导入导出，便于用户在客户端间迁移。  
> 状态：规范定稿；实现见 `docs/plans/2026-07-12-tech-stack-modernization.md` 阶段 4。

---

## 1. 设计原则

1. **互通只认 JSON 层（L1）**，不依赖任何客户端私有数据库布局。  
2. **原生 DB（L2）可选**，仅用于同一客户端快速恢复，第三方应忽略。  
3. **默认导出仅 L1**（更小、更安全、更通用）。  
4. **禁止**包含 Cookie、密码、token、图片磁盘缓存。  
5. 未知文件、未知 JSON 字段：**忽略**，不得导致导入失败。

---

## 2. 容器

| 项 | 值 |
|:---|:---|
| 扩展名 | `.s1backup.zip`（推荐）或内容符合本规范的 `.zip` |
| 压缩 | 标准 ZIP |
| 字符编码 | UTF-8 |

建议文件名：`{yyyyMMdd-HHmmss}-s1backup.zip`（允许用户自定义，扩展名保持可识别即可）。

---

## 3. 目录布局

```text
*.s1backup.zip
├── manifest.json           # 必选
├── settings.json           # 可选
├── reading_history.json    # 可选；JSON 数组
├── blacklist.json          # 可选；JSON 数组
├── poll_votes.json         # 可选；JSON 数组
└── native/                 # 可选；默认导出不包含
    └── s1er.db           # 仅本客户端高级选项
```

v1 **不使用** JSONL；列表一律为 JSON 数组。

---

## 4. `manifest.json`

```json
{
  "format": "s1-backup",
  "format_version": 1,
  "exported_at": "2026-07-12T03:25:00Z",
  "exporter": {
    "name": "s1er",
    "version": "1.0.0+1",
    "platform": "android"
  },
  "uid": "123456",
  "contents": ["settings", "reading_history", "blacklist"],
  "counts": {
    "reading_history": 128,
    "blacklist": 12
  }
}
```

| 字段 | 必选 | 说明 |
|:---|:---|:---|
| `format` | 是 | 必须为 `"s1-backup"` |
| `format_version` | 是 | 整数；导入方支持 `<=` 本机最高版本 |
| `exported_at` | 是 | ISO8601 UTC |
| `exporter` | 建议 | 导出来源；第三方可填自己的 name/version |
| `uid` | 建议 | 主要账号 uid；游客可为 `"guest"` 或省略 |
| `contents` | 是 | 包内逻辑数据集名称列表 |
| `counts` | 否 | 便于 UI 展示；可不准确，以文件内容为准 |

---

## 5. 数据集

### 5.1 `settings.json`

单个 JSON 对象。字段名稳定英文；未出现的键表示「不修改 / 使用默认」（导入方自定义策略时须在 UI 说明）。参考字段：

| 键 | 类型 | 说明 |
|:---|:---|:---|
| `theme_mode` | string | `system` / `light` / `dark` |
| `theme_color` | string | 种子色名 |
| `show_images` | bool | |
| `image_load_policy` | string | `always` / `wifi_only` / `manual`（正文图片） |
| `avatar_load_policy` | string | `always` / `wifi_only` / `manual`（头像） |
| `max_images_per_post` | int | 每楼层 inline 图片上限；`0` = 不限 |
| `image_cache_limit_mb` | int | 磁盘图片缓存上限（MB）；常见 `100` / `256` / `512` |
| `record_reading_history` | bool | |
| `font_size` | int | |
| `collapsed_forums` | string[] | 版块 id |
| `share_image_format` | string | `jpeg` / `png`；分享卡片导出图片格式 |
| `share_pixel_ratio` | int | `2` / `3`；分享卡片截图清晰度 |
| `simulate_dynamic` | bool | 调试用，可忽略 |

（实现时可与 App 内命名对齐；若内部仍用 camelCase，导出时映射到上表 snake_case，便于跨语言客户端。）

### 5.2 `reading_history.json`

数组；元素示例：

```json
{
  "uid": "123456",
  "tid": "2285124",
  "subject": "标题",
  "author": "作者",
  "fid": "4",
  "last_read_page": 2,
  "last_read_floor": 45,
  "total_pages": 10,
  "total_replies": 100,
  "per_page": 40,
  "last_read_at": 1710000000000,
  "first_read_at": 1700000000000,
  "read_count": 3
}
```

时间字段：**epoch 毫秒**。唯一逻辑键：`(uid, tid)`。

### 5.3 `blacklist.json`

数组；元素示例：

```json
{
  "uid": "10001",
  "username": "someone",
  "created_at": 1710000000000,
  "reason": "",
  "scope": ["thread", "pm"]
}
```

`scope` 取值由实现定义；未知 scope 导入时忽略该值。当前客户端约定：

- `thread` — 版块帖子列表隐藏该作者主题  
- `post` — 主题详情中折叠该作者楼层（可展开查看）  
- `pm` — 预留（可写入备份，本期不做私信筛选）

默认拉黑勾选 `thread` + `post`。

### 5.4 `poll_votes.json`

数组；元素示例：

```json
{
  "uid": "123456",
  "tid": "2285124",
  "option_ids": ["82381"]
}
```

---

## 6. 导入语义（v1）

1. 校验 `format` 与 `format_version`。  
2. 按 `contents` 与实际文件导入；缺可选文件不失败。  
3. 建议在**单事务**中写入本地库。  
4. **冲突**：同一逻辑键 **以备份为准覆盖**（v1 简单可预期；「按时间合并」留待更高 `format_version`）。  
5. 若存在 `native/s1er.db`：仅同源客户端可提示「是否用于加速恢复」；**默认仍走 JSON 导入**以保证跨版本安全。第三方应忽略 `native/`。

---

## 7. 导出语义（v1）

| 场景 | 行为 |
|:---|:---|
| 默认「导出备份」/ 上传网盘 | 仅 L1（无 `native/`） |
| 「包含原生数据库」高级选项 | 附加 `native/s1er.db`（导出前应对 SQLite 做安全 checkpoint/备份 API） |
| 敏感数据 | 不导出 Cookie、密码、token、图片缓存 |

---

## 8. 版本兼容

- 导入器必须拒绝 `format != "s1-backup"`。  
- `format_version` 高于本机支持 → 明确错误，勿部分静默导入。  
- 低版本文件：高版本导入器应可读。  
- 新增可选文件 / 字段：不升高 version 亦可，只要旧导入器可忽略。  
- 破坏性变更：升高 `format_version`，并更新本文档。

---

## 9. 第三方集成最小清单

1. 解压 ZIP，读 `manifest.json`。  
2. 映射各 JSON 到自身存储。  
3. 忽略 `native/` 与未知文件。  
4. 不向备份写入会话凭证。  

无需依赖 Flutter、Drift 或本仓库其它代码。
