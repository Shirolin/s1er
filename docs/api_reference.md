# Discuz! Mobile API Reference

S1 论坛主要使用 Discuz! Mobile API version=4；`mynotelist` 明确使用
version=3。所有请求走 `ApiConfig.mobileApiUrl`，通过 query params 指定
`module` 和 `version`。

---

## 接口清单

| Module / 端点 | 用途 | 代码位置 | 文档状态 | 实测验证 |
|-------|------|----------|----------|---------|
| `forumindex` | 首页版块分类列表 | `getForumList()` | ✅ 已完成 | ✅ 已通过 |
| `forumdisplay` | 帖子列表 | `getThreadList()` | ✅ 已完成 | ✅ 已通过 |
| `viewthread` | 帖子详情 / 回复列表 | `getThreadDetail()` | ✅ 已完成 | ✅ 已通过 |
| `login` | 登录（GET 取 formhash + POST 提交） | `login()` | ✅ 已完成 | ✅ 已通过 |
| `profile` | 用户资料 | `getUserProfile()` / `getUserProfileByUid()` | ✅ 已完成 | ✅ 已通过 |
| `newthread` | 发表新主题 | 待实现 | 📄 仅文档 | ✅ 已通过 |
| `sendpm` | 发私信 | 未使用 | ❌ 未实现 | — |
| `mypm` | 私信会话列表与详情 | `getPmList()` / `getPmConversation()` | ✅ 已完成 | ✅ 登录态只读实测 |
| `mynotelist` v3 | 帖子提醒 / 系统通知 | `getNoticeList()` | ✅ 已完成 | ✅ 两类登录态实测 |
| `sendreply` | **发回复（当前路径）** | `sendReply()` | ✅ 已完成 | ✅ 模块存在 |
| `search.php?mod=forum` | 主题搜索（HTML） | `searchForum()` | ✅ 已完成 | ✅ 302 + 移动模板实测 |
| `search.php?mod=user` | 用户搜索（HTML） | `searchUser()` | ✅ 已完成 | ✅ 302 + 强制桌面模板实测 |
| `sendpost` | ⚠️ **S1 已禁用**（勿与 sendreply 混淆） | — | ❌ 不存在 | |
| `editpost` | ⚠️ **S1 已禁用** | — | ❌ 不存在 |
| `uploadattach` / `postattach` | ⚠️ **S1 已禁用** | — | ❌ 不存在 |
| `forum.php?action=reply&repquote=` | 官方引用助手 | `fetchQuoteInfo()` | ✅ 已完成 | |
| `forum.php?mod=post&action=reply` | 旧 Web 回复（已弃用） | `sendPost()` `@Deprecated` | ⚠️ 遗留 | |
| `forum.php?mod=post&action=edit` | 编辑帖子 | 未实现 | 📄 仅文档 | — |
| 外链图床 `p.sda1.dev` | 回复插图 → `[img]url[/img]` | `ExternalImageUploadService` | ✅ 已完成 | |

---

## search.php（主题 / 用户搜索）

> 对齐 S1-Next：`POST /2b/search.php?searchsubmit=yes&mod=forum|user`，body 含 `formhash` + `srchtxt`。响应为 HTML（非 Mobile JSON）。

| | 主题 `mod=forum` | 用户 `mod=user` |
|--|------------------|-----------------|
| 入口 | 登录态「搜索」Tab → 主题 | 同 Tab → 用户 |
| 首次请求 | POST + formhash | POST + formhash |
| 翻页 | GET `pageHref`（`searchid` + `page=`） | 通常单页 |
| 解析 | 桌面 `li.pbw` / 移动 `li.list`、`div.pg` | 移动提示页继续 `forcemobile=1`，再解析 `li.bbda.cl` |
| 限流 | 用户组 `allowsearch`（常见 30s）；客户端另有 30s 提交冷却 | 同左 |

主题结果结构化为 `tid` / 标题 / 摘要 / 版块 / 作者 / 时间，点击进 `/thread/{tid}`。用户结果打开资料 sheet。

**实测**：2026-07-14 登录态低频验证通过。搜索 POST 会先返回 302；Web
代理必须将同源 `Location` 改写回本地代理。主题结果使用移动模板，用户搜索
先返回“无手机页面”提示，客户端随后只读 GET `forcemobile=1` 桌面结果页。

---

## 通用响应结构

```json
{
  "Version": "4",
  "Charset": "UTF-8",
  "Variables": {
    "cookiepre": "B7Y9_2f85_",
    "auth": "...",
    "saltkey": "...",
    "member_uid": "426519",
    "member_username": "shirolin",
    "member_avatar": "https://avatar.stage1st.com/avatar.php?uid=426519&size=small",
    "groupid": "53",
    "formhash": "58ef71fc",
    "ismoderator": "0",
    "readaccess": "100",
    "notice": {
      "newpush": "0",
      "newpm": "0",
      "newprompt": "0",
      "newmypost": "0"
    }
  }
}
```

- `auth`: Cookie 认证令牌
- `formhash`: CSRF 防护 token，POST 请求必须携带
- `member_uid`: 当前登录用户 ID，`"0"` 或空表示未登录
- 所有数值字段均为**字符串类型**，需 `int.tryParse` 解析

---

## module=forumdisplay（帖子列表）

请求参数：
- `fid`: 版块 ID
- `page`: 页码（从 1 开始）
- `tpp`: 客户端固定传 `50`
- 分类筛选时额外传独立参数 `filter=typeid` 与 `typeid={分类 ID}`

响应 `Variables` 新增字段：

### `forum` — 版块信息

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fid` | string | `"4"` | 版块 ID |
| `name` | string | `"游戏论坛"` | 版块名称 |
| `description` | string | `"游戏文化，原创，新闻"` | 版块描述（纯文本），**仅部分版块有** |
| `rules` | string? | `"刀塔的归刀塔<br />\r\n以后本区不讨论刀狗内容，刀塔主题全部回到刀区"` | 版规（含 HTML），**仅部分版块有** |
| `threads` | string | `"203692"` | 帖子总数 |
| `posts` | string | `"8789834"` | 回复总数 |
| `threadcount` | string | `"203692"` | 同 `threads`，兜底字段 |
| `fup` | string | `"1"` | 父版块 ID |
| `picstyle` | string | `"0"` | `"0"` = 关闭，`"1"` = 开启图片模式 |
| `autoclose` | string | `"0"` | 自动关闭天数，`"0"` = 不自动关闭 |
| `password` | string | `"0"` | `"0"` = 无密码，非零时需密码访问 |

### `group` — 用户组（摘要版）

`forumdisplay` 中的 `group` 只包含 `groupid` 和 `grouptitle`，不含 `forumindex` 中的完整权限列表。

### `forum_threadlist` — 帖子列表（核心）

> **坑点**：所有数值字段均为字符串，`dateline` 是日期字符串而非时间戳。

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `tid` | string | `"2206666"` | 帖子 ID |
| `subject` | string | `"帖子标题"` | 标题 |
| `author` | string | `"活久见"` | 作者用户名 |
| `authorid` | string | `"464256"` | 作者用户 ID |
| `typeid` | string | `"389"` | 主题分类 ID（对应 `threadtypes.types`，**不同版块分类不同**） |
| ~~`typename`~~ | — | — | **帖子列表不返回此字段**，需从 `threadtypes.types` 查表 |
| `dateline` | string | `"2024-11-12 19:01"` | ⚠️ **日期字符串，非时间戳** |
| `dbdateline` | string | `"1731409276"` | ✅ **Unix 时间戳（秒）**，用于显示发帖时间 |
| `lastpost` | string | `"2026-6-25 11:47"` | 最后回复时间（日期字符串） |
| `dblastpost` | string | `"1782359273"` | 最后回复 Unix 时间戳 |
| `lastposter` | string | `"grandhui"` | 最后回复者 |
| `views` | string | `"256823"` | 浏览数 |
| `replies` | string | `"318"` | 回复数 |
| `displayorder` | string | `"3"` | 显示排序（`"0"` = 普通，`>0` = 置顶） |
| `digest` | string | `"0"` | 精华标记 |
| `special` | string | `"0"` | 特殊帖子标记（`"1"` = 特殊主题） |
| `attachment` | string | `"2"` | 附件标记（`"0"` = 无附件，`>0` = 有附件） |
| `attachmentImageNumber` | string | `"1"` | 图片附件数量 |
| `readperm` | string | `"0"` | 阅读权限要求，`"0"`= 无限制 |
| `price` | string | `"0"` | 售价（死鱼），`"0"`= 免费 |
| `recommend_add` | string | `"0"` | 推荐/赞数 |
| `recommend` | string | `"0"` | 推荐/赞数（与 `recommend_add` 同时存在） |
| `replycredit` | string | `"0"` | 回复奖励 |
| `rushreply` | string | `"0"` | 抢楼标记 |
| `message` | string | — | 帖子正文（截断，含 BBCode） |

#### `reply[]` — 最近回复预览（数组，最多 3 条）

| 字段 | 类型 | 说明 |
|------|------|------|
| `pid` | string | 回复 ID |
| `author` | string | 回复者用户名 |
| `authorid` | string | 回复者用户 ID |
| `message` | string | 回复内容（截断） |

#### `attachmentImagePreviewList[]` — 图片附件预览（数组，可能为空 `[]`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `aid` | string | 附件 ID |
| `tid` | string | 帖子 ID |
| `pid` | string | 所属回复 ID |
| `uid` | string | 上传者 ID |
| `dateline` | string | 上传时间（Unix 时间戳字符串） |
| `filename` | string | 文件名 |
| `filesize` | string | 文件大小（字节） |
| `attachment` | string | 存储路径 |
| `isimage` | string | `"1"` = 是图片 |
| `width` | string | 图片宽度 |
| `height` | string | 图片高度 |
| `thumb` | string | 缩略图标记 |

> **客户端图片策略**（对齐 [S1-Next](https://github.com/ykrank/S1-Next)）：帖子正文以 `viewthread` → `postlist[].message` 内嵌 HTML 为准，**只信任服务端提供的 `<img src>`**（及可选的 `<a href>` 原图链接），不猜测 `.thumb.jpg` 或构造 `forum.php?mod=image` URL。inline 与全屏共用同一 URL；省流量靠 **下载门控**（始终 / 仅 Wi-Fi / 手动）、**每楼层 inline 图片张数上限**（默认 10，0 = 不限；超出显示「展开」且不挂载 `ImageViewer`）、**可配置磁盘缓存上限**（默认 256MB，可选 100/256/512）与 **客户端 `ResizeImage` 降采样**，磁盘仍缓存原图字节供全屏复用。头像可单独配置加载策略（始终 / 仅 Wi-Fi / 手动）；已磁盘缓存的头像不受门控阻塞。全屏看图不受正文图片门控限制。`attachmentImagePreviewList` 主要用于 **forumdisplay 列表封面**，详情页正文暂不依赖该字段。

### `threadtypes` — 主题分类映射（不同版块不同）

动漫论坛（fid=6）的分类：
```json
{
  "types": {
    "14": "求助",   "15": "原创",   "16": "新闻",   "17": "讨论",
    "18": "新番",   "19": "分享",   "20": "恶搞",   "21": "声优",
    "75": "怀旧",   "76": "活动",   "179": "列举",  "180": "求战",
    "181": "推荐",  "289": "连载",  "290": "漫画"
  }
}
```

游戏论坛（fid=4）的分类：
```json
{
  "types": {
    "1": "其他",   "3": "PSP",     "5": "PS3",     "7": "XBOX",
    "8": "PC",     "9": "怀旧",    "10": "多平台", "11": "3DS",
    "12": "新闻",  "13": "资源",   "73": "手游",   "77": "PSVita",
    "128": "Wii U", "175": "青黑无脑不要游戏只求一战",
    "232": "PS4/5", "233": "页游", "234": "NDS",   "235": "WII",
    "236": "PS2",  "238": "汉化",  "312": "NS"
  }
}
```

> 用 `thread.typeId` 查 `threadtypes.types` 获取分类名称。`typeid` 在不同版块含义不同。

### `tpp` — 每页帖子数

```json
"tpp": "50"
```

用于计算帖子列表总页数：`totalPages = ceil(threadcount / tpp)`

### `groupiconid` — 用户组图标映射

以 `authorid` 为 key，值为图标 ID 字符串（如 `"admin"`、`"special"`、数字）。

### `sublist` — 子版块列表

| 字段 | 类型 | 说明 |
|------|------|------|
| `fid` | string | 子版块 ID |
| `name` | string | 子版块名称 |
| `threads` | string | 帖子数 |
| `posts` | string | 回复数 |
| `todayposts` | string | 今日帖子数 |

---

## module=forumindex（首页版块列表）

请求参数：无（需要已登录状态的 Cookie）

响应 `Variables` 中，除通用字段外，额外返回：

### 用户额外信息

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `member_email` | string | `"user@example.com"` | 用户邮箱 |
| `member_credits` | string | `"147030"` | 用户总积分 |
| `setting_bbclosed` | string | `"0"` | `"0"`=开放，`"1"`=关闭 |

### `group` — 当前用户组权限（完整）

响应中的 `group` 对象包含 `groupid`、`grouptitle` 以及上百个 `allow*` 权限字段：

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `groupid` | string | `"53"` | 用户组 ID |
| `grouptitle` | string | `"半肾"` | 用户组名称 |
| `allowvisit` | string | `"1"` | 允许访问 |
| `allowpost` | string | `"1"` | 允许发帖 |
| `allowreply` | string | `"1"` | 允许回复 |
| `allowpostattach` | string | `"1"` | 允许上传附件 |
| `allowpostimage` | string | `"1"` | 允许上传图片 |
| `allowsendpm` | string | `"1"` | 允许发私信 |
| `allowsearch` | string | `"30"` | 搜索间隔（秒） |
| `allowavatarupload` | string | `"1"` | 允许上传头像 |
| … | … | … | 其余 `allow*` 字段省略 |

### `catlist` — 分类列表

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fid` | string | `"117"` | 分类 ID |
| `name` | string | `"热门新区"` | 分类名称 |
| `forums` | array[string] | `["156","138",…]` | 该分类下的版块 fid 列表（对应 `forumlist`） |

### `forumlist` — 版块详情列表

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fid` | string | `"6"` | 版块 ID |
| `name` | string | `"动漫论坛"` | 版块名称 |
| `description` | string? | `"清明快到了"` | 版块描述，**仅部分版块有** |
| `threads` | string | `"192471"` | 帖子总数 |
| `posts` | string | `"10776074"` | 回复总数 |
| `todayposts` | string | `"180"` | 今日发帖数 |
| `sublist` | array? | — | 子版块列表，**仅部分版块有** |

#### `sublist` 子版块

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fid` | string | `"83"` | 版块 ID |
| `name` | string | `"动漫投票鉴赏"` | 版块名称 |
| `threads` | string | `"3064"` | 帖子数 |
| `posts` | string | `"45247"` | 回复数 |
| `todayposts` | string | `"0"` | 今日发帖数 |

---

## module=viewthread（帖子详情）

请求参数：
- `tid`: 帖子 ID
- `page`: 页码（从 1 开始）

### `thread` — 帖子元信息

> **注意**：`viewthread` 中 `thread.dateline` 是 **Unix 时间戳字符串**，与 `forumdisplay` 的 `dbdateline` 一致。

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `tid` | string | `"2285169"` | 帖子 ID |
| `fid` | string | `"4"` | 版块 ID |
| `typeid` | string | `"8"` | 主题分类 ID |
| `author` | string | `"m1grandmk1"` | 楼主用户名 |
| `authorid` | string | `"577038"` | 楼主用户 ID |
| `subject` | string | `"八方2打完了，下一个游戏怎么选"` | 标题 |
| `short_subject` | string | — | 缩短的标题 |
| `dateline` | string | `"1783481855"` | ✅ **Unix 时间戳**，可直接 `int.tryParse` |
| `lastpost` | string | `"2026-7-8 13:15"` | 最后回复时间（日期字符串） |
| `lastposter` | string | `"猪突猛进R"` | 最后回复者 |
| `views` | string | `"201"` | 浏览数 |
| `replies` | string | `"3"` | 回复数 |
| `allreplies` | string | `"3"` | 总回复数（含隐藏） |
| `maxposition` | string | `"4"` | 最大楼层号 |
| `displayorder` | string | `"0"` | 排序（`>0` = 置顶） |
| `readperm` | string | `"0"` | 阅读权限 |
| `price` | string | `"0"` | 售价 |
| `special` | string | `"0"` | 特殊帖子标记 |
| `digest` | string | `"0"` | 精华标记 |
| `recommends` | string | `"0"` | 推荐总数 |
| `recommend_add` | string | `"0"` | 推荐加分 |
| `recommend_sub` | string | `"0"` | 推荐减分 |
| `heats` | string | `"468"` | 热度 |
| `favtimes` | string | `"5"` | 收藏次数 |
| `sharetimes` | string | `"0"` | 分享次数 |
| `attachment` | string | `"0"` | 附件标记 |
| `closed` | string | `"0"` | `"1"` = 帖子已关闭 |
| `hidden` | string | `"0"` | 隐藏标记 |
| `status` | string | `"32"` | 帖子状态位 |
| `highlight` | string | `"0"` | 高亮标记 |
| `stamp` | string | `"-1"` | 印章 ID，`"-1"` = 无印章 |
| `icon` | string | `"-1"` | 图标 ID，`"-1"` = 无图标 |
| `replycredit` | string | `"0"` | 回复奖励金额 |
| `ordertype` | string | `"0"` | 排序类型 |
| `relay` | string | `"0"` | 转发数 |
| `recommend` | string | `"0"` | 推荐标记 |
| `comments` | string | `"0"` | 评论数 |
| `moderated` | string | `"0"` | 是否被管理操作 |
| `isgroup` | string | `"0"` | 是否为群组帖子 |
| `posttableid` | string | `"0"` | 分表 ID，`"0"` = 主表 |
| `sortid` | string | `"0"` | 分类信息 ID，`"0"` = 无 |
| `rate` | string | `"0"` | 评分标记 |
| `stickreply` | string | `"0"` | 置顶回复标记 |
| `relatebytag` | string | `"0"` | 关联标签 |
| `recommendlevel` | string | `"0"` | 推荐等级 |
| `heatlevel` | string | `"0"` | 热度等级 |
| `pushedaid` | string | `"0"` | 推送附件 ID |
| `cover` | string | `"0"` | 封面标记 |
| `addviews` | string | `"8"` | 本次新增浏览量（用于增量统计） |
| `short_subject` | string | — | 截断后的短标题 |
| `subjectenc` | string | — | URL 编码后的标题 |
| `replycredit_rule` | object? | — | 回复奖励规则，如 `{"extcreditstype":"5"}`（奖励死鱼） |
| `threadtable` | string | `"forum_thread"` | 帖子所属表名 |
| `threadtableid` | string | `"0"` | 帖子分表 ID |
| `posttable` | string | `"forum_post"` | 回复所属表名 |
| `is_archived` | string | `""` | 归档状态，非空 = 已归档 |

### `postlist` — 回复列表（核心）

> **坑点**：与 `forumdisplay` 一样，`dateline` 是日期字符串，`dbdateline` 才是 Unix 时间戳。
> 实测发现 `first: "1"` 的楼主帖也包含在 `postlist` 中，可通过 `first` 字段过滤。

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `pid` | string | `"69888584"` | 回复 ID |
| `tid` | string | `"2285169"` | 帖子 ID |
| `first` | string | `"1"` | `"1"` = 楼主帖（首帖），`"0"` = 普通回复 |
| `author` | string | `"m1grandmk1"` | 作者用户名 |
| `authorid` | string | `"577038"` | 作者用户 ID |
| `username` | string | — | 用户名（同 `author`） |
| `dateline` | string | `"2026-7-8 11:37"` | ⚠️ **日期字符串** |
| `dbdateline` | string | `"1783481855"` | ✅ **Unix 时间戳** |
| `message` | string | — | 回复内容（**含 HTML 标签**，如 `<font>`、`<img>`、`<br>`） |
| `number` | string | `"1"` | ✅ **楼层号**（`"1"` = 楼主，`"2"`+ = 回复） |
| `position` | string | `"1"` | 位置号（通常同 `number`） |
| `groupid` | string | `"54"` | 用户组 ID |
| `groupiconid` | string? | `"13"` | 用户组图标 ID，**被禁言用户为 `null`** |
| `adminid` | string | `"0"` | 管理员 ID（`"-1"` = 被禁言） |
| `attachment` | string | `"0"` | 附件标记，`">0"` = 有附件 |
| `anonymous` | string | `"0"` | `"1"` = 匿名回复 |
| `status` | string | `"0"` | 状态位（`"1024"` = 可能含删除标记） |
| `memberstatus` | string | `"0"` | 成员状态 |
| `replycredit` | string | `"0"` | 回复奖励 |

### `ppp` — 每页帖数

```json
"ppp": "40"
```

用于计算帖子详情页总页数：`totalPages = ceil(replies / ppp)`

### `forum` — 版块信息（摘要版）

`viewthread` 中只返回 `password` 字段。

---

## module=login（登录）

请求参数：
- GET: 获取 `formhash`（未登录时返回正常，已登录时返回 `login_succeed`）
- POST: 提交登录表单

额外响应字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `loginUrl` | string? | WSQ 扫码登录链接（仅在已登录时返回） |

POST 字段：

| 字段 | 必填 | 说明 |
|------|------|------|
| `formhash` | ✅ | CSRF token |
| `fastloginfield` | ✅ | 固定 `"username"` |
| `username` | ✅ | 用户名 |
| `password` | ✅ | 密码 |
| `questionid` | ✅ | 安全提问 ID（见下表），`"0"` = 无安全提问 |
| `answer` | ✅ | 安全提问答案，`questionid="0"` 时传空字符串 `""` |
| `cookietime` | ❌ | 登录有效期，`"2592000"`（30天），默认 1 小时 |

安全提问 ID 映射（Discuz! 语言包 / S1-Next 一致）：

| `questionid` | 说明 |
|:---|:---|
| `"0"` | 安全提问（未设置请忽略） |
| `"1"` | 母亲的名字 |
| `"2"` | 爷爷的名字 |
| `"3"` | 父亲出生的城市 |
| `"4"` | 您其中一位老师的名字 |
| `"5"` | 您个人计算机的型号 |
| `"6"` | 您最喜欢的餐馆名称 |
| `"7"` | 驾驶执照最后四位数字 |

响应 `Message.messageval`：
- `"login_succeed"` → 登录成功
- 其他 → 登录失败；优先展示已翻译的 `messagestr`（S1-Next 风格补全句号），裸 key（如 `mobile:login_invalid`）由客户端映射为中文

---

## module=sendreply（发回复，当前实现）

> 对齐 S1-Next：`POST api/mobile/index.php?module=sendreply&replysubmit=yes&version=4`。
> **注意**：`module=sendpost` 在 S1 返回 `module_not_exists`，与 `sendreply` 不是同一模块。

### POST 字段

| 字段 | 必填 | 说明 |
|------|------|------|
| `formhash` | ✅ | 由 `S1HttpClient` 注入 |
| `tid` | ✅ | 主题 ID |
| `message` | ✅ | **仅用户正文**（可含 `[img]url[/img]`），不含客户端拼的 `[quote]` |
| `noticeauthor` | 引用时 | 来自官方 quote helper（服务端编码 ID，非用户名） |
| `noticetrimstr` | 引用时 | helper 返回的引用片段（含 findpost / 常带 `[post]`） |
| `noticeauthormsg` | 引用时 | 用户正文缩写，上限约 100 字 |

成功：`Message.messageval` 含 `succeed`（如 `post_reply_succeed`）。

### 官方引用助手

```
GET forum.php?mod=post&action=reply&inajax=yes&tid={tid}&repquote={pid}
```

解析 hidden：`noticeauthor`、`noticetrimstr`。

### 引用块跳转契约

跳转读 **viewthread 展示 HTML**：`QuoteBlock` 从引用段提取 `goto=findpost` 且含 `ptid=`（缺省用当前帖 `currentTid` + `pid`）。
勿依赖「发帖时客户端嵌进 message 的 BBCode 文本」作为跳转来源。

### 插图

上传至 `https://p.sda1.dev/api/v1/upload_external_noform?filename=`（原始字节，非 multipart），
将返回的 `data.url` 以 `[img]…[/img]` 写入 `message`。不做 Discuz `aid` 附件。
**Web**：浏览器直连图床会 CORS 失败，经开发代理 `POST /ext-upload?filename=` 转发到同上游 URL（`scripts/proxy_server.dart`）。Native 仍直连。

---

## module=sendpost（已禁用，历史说明）

> Mobile API 方式（`api/mobile/index.php?module=sendpost`）用于**第三方客户端**，返回 JSON。
> 以下浏览器端点（`forum.php`）仅供参考/调试，理解 Discuz! 内部运行机制。
> 移动端 web 版仅在 URL 上增加 `&mobile=2` 参数，其他机制相同。

---

### Mobile API 方式 ⚠️ S1 不支持

**实测结果**：`api/mobile/index.php?module=sendpost` → `{"error":"module_not_exists"}`。

S1 **未启用** `sendpost`；当前回复请用 **`module=sendreply`**（见上一节）。

---

### 浏览器端点参考（历史 / 调试）

以下端点来自浏览器真实请求；**回复提交通道已切换到 sendreply**，下列 XML 回复路径仅作遗留对照。

#### 1. 上传附件（Discuz 原生，本期不做）

请求：
- URL: `$baseUrl/misc.php`
- Method: POST
- Content-Type: `multipart/form-data`
- Query: `mod=swfupload&operation=upload&type=attach&inajax=yes&infloat=yes`
- Cookie: 需要已登录态
- Referer: `forum.php?mod=post&action=reply&fid={fid}&tid={tid}&reppost=0&page={page}&mobile=2`

multipart 字段（HTTP body）：

| 字段 | 说明 |
|------|------|
| `Filedata` | 文件二进制数据 |

具体实现时建议通过 `multipart/form-data` POST 上传文件。

---

### 2. 检查发帖规则（checkpostrule）

请求：
- URL: `$baseUrl/forum.php`
- Method: GET
- Query: `mod=ajax&action=checkpostrule&inajax=yes&ac=reply&infloat=yes&handlekey=reply`
- Headers: `x-requested-with: XMLHttpRequest`
- Cookie: 需要已登录态

响应（XML）：
```xml
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[]]></root>
```
空 CDATA 表示允许发帖。

---

### 3. 提交回复

请求（PC 端）：
- URL: `$baseUrl/forum.php`
- Method: POST
- Content-Type: `application/x-www-form-urlencoded`
- Query: `mod=post&infloat=yes&action=reply&fid={fid}&extra=&tid={tid}&replysubmit=yes&inajax=1`

请求（移动端）：
- URL: `$baseUrl/forum.php`
- Method: POST
- Content-Type: `multipart/form-data`
- Query: `mod=post&action=reply&fid={fid}&tid={tid}&extra=&replysubmit=yes&mobile=2&geoloc=&handlekey=postform&inajax=1`

| 字段 | 必填 | 说明 |
|------|------|------|
| `formhash` | ✅ | CSRF token，从通用响应中获取 |
| `message` | ✅ | 回复内容，图片使用 `[attach]N[/attach]` BBCode |
| `posttime` | ✅ | 当前 Unix 时间戳（移动端必填） |
| `handlekey` | ❌ | 固定 `"reply"`（PC）或 `"postform"`（移动端） |
| `usesig` | ❌ | `"1"` = 使用签名 |
| `noticeauthor` | ❌ | 引用回复时被 @ 的用户名 |
| `noticetrimstr` | ❌ | 引用回复的 trim 串 |
| `noticeauthormsg` | ❌ | 引用回复的消息原文 |
| `subject` | ❌ | 主题（回复时通常为空） |
| `replysubmit` | ❌ | 固定 `"yes"` |
| `geoloc` | ❌ | 地理位置（移动端） |
| `attachnew[N][description]` | ❌ | 附件描述，如 `"由手机上传"`（移动端 multipart） |

响应（XML + JavaScript callback）：
```xml
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[<script type="text/javascript" reload="1">
if(typeof succeedhandle_reply=='function') {
  succeedhandle_reply(
    'forum.php?mod=viewthread&tid={tid}&pid={pid}&page={page}&extra=#pid{pid}',
    '非常感谢，回复发布成功，现在将转入主题页，请稍候……[ 点击这里转入主题列表 ]',
    {'fid':'{fid}','tid':'{tid}','pid':'{pid}','from':'','sechash':''}
  );
}
</script>]]></root>
```

成功关键数据：`pid`（回复 ID）、`tid`、`fid`。

---

### 4. 获取新回复 HTML

请求：
- URL: `$baseUrl/forum.php`
- Method: GET
- Query: `mod=viewthread&tid={tid}&viewpid={pid}&inajax=1&ajaxtarget=post_new`
- Headers: `x-requested-with: XMLHttpRequest`
- Cookie: 需要已登录态

响应是一个完整的 `<table id="pid{pid}">` HTML 块，包含新回复的：
- 作者信息（用户名、UID、头像、用户组、积分、战斗力、回帖数）
- 楼层号（`<em>N</em><sup>#</sup>`）
- 发布时间
- 回复正文

注意：此 HTML 是 Discuz! 前端直接渲染用的，**不含 JSON 结构**。

---

### 5. 编辑帖子

请求：
- URL: `$baseUrl/forum.php`
- Method: POST
- Content-Type: `multipart/form-data`
- Query: `mod=post&action=edit&extra=&editsubmit=yes&mobile=2&geoloc=&handlekey=postform&inajax=1`
- Headers: `x-requested-with: XMLHttpRequest`
- Cookie: 需要已登录态

| 字段 | 必填 | 说明 |
|------|------|------|
| `formhash` | ✅ | CSRF token |
| `posttime` | ✅ | 当前 Unix 时间戳 |
| `fid` | ✅ | 版块 ID |
| `tid` | ✅ | 帖子 ID |
| `pid` | ✅ | 要编辑的回复 ID |
| `message` | ✅ | 编辑后的内容 |
| `page` | ❌ | 当前页码 |
| `subject` | ❌ | 主题（回复编辑时通常为空） |
| `usesig` | ❌ | `"1"` = 使用签名 |
| `editsubmit` | ❌ | 固定 `"yes"` |
| `attachnew[N][description]` | ❌ | 附件描述 |
| `attachnew[N][readperm]` | ❌ | 附件阅读权限 |

---

## module=profile（用户资料）

请求参数：
- `uid`: 用户 ID

### `space` — 用户信息

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `uid` | string | `"426519"` | 用户 ID |
| `username` | string | `"shirolin"` | 用户名 |
| `avatarstatus` | string | `"1"` | `"1"` = 已设置头像 |
| `groupid` | string | `"53"` | 用户组 ID |
| `adminid` | string | `"0"` | 管理员 ID |
| `regdate` | string | `"2015-5-10 23:33"` | 注册时间（日期字符串） |
| `credits` | string | `"147100"` | 总积分 |
| `posts` | string | `"2042"` | 发帖数 |
| `threads` | string | `"4"` | 主题数 |
| `digestposts` | string | `"0"` | 精华帖数 |
| `friends` | string | `"0"` | 好友数 |
| `follower` | string | `"3"` | 粉丝数 |
| `following` | string | `"0"` | 关注数 |
| `newfollower` | string | `"3"` | 新粉丝数 |
| `blacklist` | string | `"12"` | 黑名单人数 |
| `oltime` | string | `"14710"` | 在线时长（小时） |
| `views` | string | `"0"` | 空间被访问数 |
| `lastvisit` | string | `"2026-7-8 15:36"` | 最后访问时间 |
| `lastactivity` | string | `"2026-7-8 15:05"` | 最后活跃时间 |
| `lastpost` | string | `"2026-7-8 15:27"` | 最后发帖时间 |
| `gender` | string | `"0"` | `"0"` = 保密，`"1"` = 男，`"2"` = 女 |
| `site` | string | — | 个人网站 |
| `bio` | string | — | 个人简介 |
| `interest` | string | — | 兴趣爱好 |
| `recentnote` | string | — | 最近状态/签名 |
| `spacenote` | string | — | 空间公告 |
| `self` | string | `"1"` | `"1"` = 查看自己的资料 |
| `attachsize` | string | `"   0 B "` | 附件总大小 |
| `todayattachs` | string | `"4"` | 今日上传附件数 |
| `extcredits1` | string | `"84"` | 扩展积分1（战斗力/鹅） |
| `extcredits5` | string | `"3207"` | 扩展积分5（死鱼/条） |
| `upgradecredit` | string | `"2900"` | 距离下一用户组还需的积分数 |
| `upgradeprogress` | string | `"94"` | 升级进度百分比（`"0"`–`"100"`） |
| `secmobile` | string | — | 绑定的手机号，**仅自己可见，他人查不到** |

### `space.group` — 用户组

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `type` | string | `"member"` | 用户组类型 |
| `grouptitle` | string | `"半肾"` | 用户组名称 |
| `creditshigher` | string | `"100000"` | 积分下限 |
| `creditslower` | string | `"150000"` | 积分上限 |
| `readaccess` | string | `"100"` | 阅读权限 |
| `stars` | string | `"0"` | 星星数 |
| `color` | string | — | 用户名颜色 |
| `icon` | string | — | 组图标 |
| `allowmediacode` | string | `"1"` | 允许多媒体代码 |
| `allowgetattach` | string | `"1"` | 允许下载附件 |
| `allowgetimage` | string | `"1"` | 允许查看图片 |
| `maxsigsize` | string | `"100"` | 最大签名长度 |
| `allowbegincode` | string | `"0"` | 允许 [begin] 代码 |
| `userstatusby` | string | `"1"` | 用户状态依据 |

### `extcredits` — 扩展积分配置

以 `extcredits` ID 为 key，每项包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `title` | string | 积分名称 |
| `unit` | string | 单位 |
| `ratio` | string | 兑换比率 |
| `img` | string | 图标（通常为空） |

S1 实际配置：

```json
{
  "1":  {"title": "战斗力", "unit": "鹅",  "ratio": "0"},
  "4":  {"title": "人品",   "unit": "RP",  "ratio": "50"},
  "5":  {"title": "死鱼",   "unit": "条",  "ratio": "10"},
  "7":  {"title": "节操",   "unit": "斤",  "ratio": "1"}
}
```

### `space.privacy` — 隐私设置

包含 `feed`（动态）、`view`（查看）、`profile`（资料字段）的隐私级别映射。

---

## module=sendpm（发私信）

> 未实现。`ApiConfig.moduleSendMessage` 已定义但无调用代码。

---

## module=mypm（私信会话列表与详情）

获取当前登录用户的私信会话列表。未登录时 `Message.messageval` 为 `login_before_enter_home`。

### 请求参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `page` | ❌ | 页码，从 1 开始 |

### 响应 `Variables` 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `list` | array | 会话列表 |
| `count` | string? | 总会话数（可能为 null） |
| `perpage` | string? | 每页条数（可能为 null，默认按 20 处理） |
| `page` | string | 当前页 |

### `list[]` 每项字段（Discuz 标准 + S1 实测结构）

| 字段 | 类型 | 说明 |
|------|------|------|
| `touid` | string | 对话对象 UID（兜底：`msgtoid`、`uid`） |
| `msgfrom` | string | 最后一条消息发送者用户名 |
| `msgfromid` | string | 最后一条消息发送者 UID（兜底：`authorid`） |
| `tousername` | string? | 对话对象用户名（兜底：`touuser`、`msgto`、`toname`） |
| `message` | string | 最后一条消息摘要（兜底：`lastmessage`、`lastsummary`、`summary`） |
| `dateline` | string | Unix 时间戳（兜底：`dbdateline`；或 `date` / `pmdate` / `postdatetime` 日期串） |
| `avatar` | string? | 头像 URL（兜底：`member_avatar`、`msgfromavatar`） |

> 判断方向：`msgfromid == touid` 为对方发来；否则为自己发出。

### HTML 兜底

当 API 返回空列表或解析失败时，客户端回退到：

`home.php?mod=space&do=pm&filter=privatepm&page={page}`

解析 `#pmlist ul li`：`touid`、头像、`.mtime`、`.mtit`、`.mtxt`。

### 会话详情

请求 `module=mypm&subop=view&touid={对话对象 UID}&page={page}`。响应
`Variables.list[]` 解析 `pmid/plid`、`msgfromid`、`msgfrom`、`message` 和
`dateline`；以 `msgfromid == touid` 判断对方发来，否则为自己发出。

分页使用 `count/perpage/page`。当前解析契约由 S1-Next 模型和完全合成的
fixture 覆盖，尚未使用真实账号响应复核。

---

## module=mynotelist v3（我的提醒）

客户端使用 version=3，并按需请求两个分类：

- 帖子提醒：`view=mypost&type=post`
- 系统通知：`view=system&type=post`

响应解析 `Variables.count/page/perpage/list`。`list[]` 使用 `id`、`author`、
`authorid`、`dateline`、`new` 与 `note`；从 `note` HTML 提取纯文本摘要和
可选的 `ptid/pid` 跳转目标。系统通知允许没有作者和帖子目标。

version=4 不可用。当前 v3 字段契约由 S1-Next 模型和完全合成的 fixture
覆盖，尚未使用真实账号响应复核。

### HTML 兼容兜底

JSON 非法、模块不可用或缺少 `Variables.list` 时，回退相同分类：

`home.php?mod=space&do=notice&view={mypost|system}&type=&isread=1&page={page}`

登录错误直接上抛，合法空 JSON 列表不触发兜底。

### 列表项

- `li[notice]` → 提醒 ID
- `.mimg a[href*=uid=]` → 作者 UID；链接文本为头像 URL
- `.mtit span`（非「屏蔽」链接）→ 时间
- `.mbody` → 正文 HTML；从 `goto=findpost&ptid=&pid=` 提取跳转目标

### 分页

`.pg` 中 `page=N` 链接的最大 N 为总页数；`class="last"` 含末页页码。

---

## module=mythread（用户空间：我的主题 / 回复）

仅返回**当前登录用户**的数据。查看其他用户需通过 HTML 解析 `home.php?mod=space&uid=X&do=thread&type=thread|reply`。

### 请求参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `type` | ❌ | `"thread"`（默认）= 用户创建的主题，`"reply"` = 用户回复过的主题 |
| `page` | ❌ | 页码，从 1 开始 |

### 响应 `Variables` 新增字段

#### `data` — 主题列表（核心）

两种 `type` 共用同一响应结构。

| 字段 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `tid` | string | `"2274556"` | 主题 ID |
| `fid` | string | `"51"` | 版块 ID |
| `subject` | string | `"搞了个X(Twitter)拼图拆图用的浏览器扩展"` | 标题 |
| `author` | string | `"shirolin"` | 作者用户名 |
| `authorid` | string | `"426519"` | 作者用户 ID |
| `dateline` | string | `"2026-2-11 19:40"` | ⚠️ **日期字符串**（`type=reply` 时为此主题的原始发帖时间） |
| `dbdateline` | string | `"1770810009"` | ✅ **Unix 时间戳** |
| `lastpost` | string | `"2026-3-12 20:00"` | 最后回复时间 |
| `lastposter` | string | `"勿徨哉"` | 最后回复者 |
| `views` | string | `"2953"` | 浏览数 |
| `replies` | string | `"11"` | 回复数 |
| `displayorder` | string | `"0"` | 排序，`>0` = 置顶 |
| `special` | string | `"0"` | 特殊帖子标记 |
| `attachment` | string | `"0"` | 附件标记 |
| `fname` | — | — | ⚠️ **此接口不返回版块名称**，需要 `fid` 自行查表 |

> **注意**：`type=reply` 返回的是用户**回复过的主题列表**（不含具体的回复内容）。
> 要获取每条回复的 `pid` 和摘要，需通过 HTML 解析 `home.php?mod=space&uid=X&do=thread&type=reply`。

#### `perpage` — 每页条数

```json
"perpage": "50"
```

无总条数字段。分页通过判断 `data` 长度是否等于 `perpage` 来推算是否有下一页。

---

## HTML 解析：用户空间（主题 / 回复）

`mythread` API 仅返回当前用户数据。查看任意用户（含他人）的空间列表需解析 `home.php` 的 HTML。

### 主题列表

- URL: `{baseUrl}/home.php?mod=space&uid={uid}&do=thread&view=me&type=thread&from=space&page={page}`
- 需要登录 Cookie
- 每条主题含：`tid`、标题、版块名、回复/查看数、最后回复时间

### 回复列表

- URL: `{baseUrl}/home.php?mod=space&uid={uid}&do=thread&view=me&type=reply&from=space&page={page}`
- 需要登录 Cookie
- 结构为**主题 + 该用户在此主题下的多条回复**，每行格式：

```html
<!-- 主题标题行（<tr class="bw0_all">）→ 提取 tid、subject、forum -->
<!-- 回复行（<tr><td colspan="5">）→ 提取 pid、回复摘要 -->
<a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid={tid}&amp;pid={pid}">回复内容摘要</a>
```

- `tid` / `pid` 均从 `goto=findpost&ptid={tid}&pid={pid}` 链接中解析

### 分页

响应 HTML 中通过 `class="nxt"`（下一页）和 `page=N` 标签推断总页数。

---

## Mobile API 模块可用性总表

以下为对 `api/mobile/index.php?module={name}&version=4` 的实测结果（GET，未登录）。注意：S1 可能随维护策略调整游客访问权限，表格记录当前验证结果。

| 模块 | 响应 | 状态 |
|------|------|------|
| `forumindex` | `{"error":"to_login"}` | ⚠️ 当前未登录不可读 |
| `forumdisplay` | `{"error":"to_login"}` | ⚠️ 当前未登录不可读 |
| `viewthread` | 历史曾可读；当前应按可能返回 `to_login` 处理 | ⚠️ 取决于 S1 当前策略 |
| `mythread` | 返回 JSON，未登录时提示 `to_login` | ✅ 可用（仅当前用户） |
| `login` | 正常返回 JSON | ✅ 可用 |
| `profile` | 正常返回 JSON | ✅ 可用 |
| `newthread` | 返回 JSON，缺参数时提示 `forum_nonexistence` | ✅ 可用（发新帖） |
| `sendpm` | 返回 JSON，未登录时提示 `to_login` | ✅ 可用（发私信） |
| `mypm` | 返回 JSON，`list` 字段；未登录 `login_before_enter_home` | ✅ 可用（私信列表） |
| `mynotelist` | version=3 返回 JSON；客户端按 mypost/system 使用，HTML 同分类兜底 | ✅ 已采用（待真实登录态复核） |
| `sendreply` | 游客探测可进入 `api/4/sendreply.php`；正式回复需登录 | ✅ 可用（发回复） |
| `sendpost` | `{"error":"module_not_exists"}` | ❌ S1 已禁用 |
| `editpost` | `{"error":"module_not_exists"}` | ❌ S1 已禁用 |
| `uploadattach` | `{"error":"module_not_exists"}` | ❌ S1 已禁用 |
| `postattach` | `{"error":"module_not_exists"}` | ❌ S1 已禁用 |
| `checkpostrule` | `{"error":"module_not_exists"}` | ❌ S1 已禁用 |
| 其余 20+ 模块 | `{"error":"module_not_exists"}` | ❌ 均不可用 |

结论：S1 的 Mobile API **开放能力会受当前论坛登录策略影响**。客户端应允许未登录进入只读入口，但任何读接口返回 `to_login` 时都必须降级为登录提示。**发回复走 `module=sendreply`**；`sendpost`/编辑/附件上传模块仍禁用。用户空间列表的回复摘要数据也需走 HTML 解析。

---

## 已知陷阱

1. **`dateline` ≠ 时间戳**：帖子列表中 `dateline` 是 `"YYYY-M-D H:mm"` 格式字符串，必须用 `dbdateline`（Unix 秒）作为时间戳
2. **所有数值字段均为字符串**：`views`、`replies`、`tid` 等都需要 `int.tryParse`
3. **`typename` 不在帖子列表中**：需通过 `typeid` 查 `threadtypes.types` 映射表
4. **`message` 字段截断**：帖子列表中的 `message` 是正文摘要，非完整内容
5. **`ppp`（每页帖数）各不相同**：`forumdisplay` 用 `tpp=50` 算帖子列表页数，`viewthread` 用 `ppp=40` 算帖子详情页数，代码中不能混用或硬编码
6. **CORS 限制**：Web 端需通过代理服务器访问 API
