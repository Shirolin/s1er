# Discuz! Mobile API Reference

S1 论坛使用的 Discuz! Mobile API (version=4)。所有请求走 `ApiConfig.mobileApiUrl`，通过 query params 指定 `module` 和 `version`。

---

## 接口清单

| Module | 用途 | 代码位置 | 文档状态 |
|--------|------|----------|----------|
| `forumindex` | 首页版块分类列表 | `getForumList()` | ✅ 已完成 |
| `forumdisplay` | 帖子列表 | `getThreadList()` | ✅ 已完成 |
| `viewthread` | 帖子详情 / 回复列表 | `getThreadDetail()` | ✅ 已完成 |
| `login` | 登录（GET 取 formhash + POST 提交） | `login()` | ✅ 已完成 |
| `sendpost` | 发回复 | `sendPost()` | ✅ 已完成 |
| `sendpm` | 发私信 | 未使用 | ❌ 未实现 |
| `profile` | 用户资料 | `getUserProfile()` / `getUserProfileByUid()` | ✅ 已完成 |

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

响应 `Variables` 新增字段：

### `forum` — 版块信息

| 字段 | 类型 | 说明 |
|------|------|------|
| `fid` | string | 版块 ID |
| `name` | string | 版块名称 |
| `description` | string | 版块描述（纯文本） |
| `rules` | string? | 版规（含 HTML），**部分版块有** |
| `threads` | string | 帖子总数 |
| `posts` | string | 回复总数 |
| `threadcount` | string | 同 `threads`，兜底字段 |
| `fup` | string | 父版块 ID |
| `picstyle` | string | `"0"` = 关闭，`"1"` = 开启图片模式 |
| `autoclose` | string | 自动关闭天数，`"0"` = 不自动关闭 |
| `password` | string | `"0"` = 无密码，非零时需密码访问 |

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
| `heats` | string | `"3"` | 热度 |
| `favtimes` | string | `"0"` | 收藏次数 |
| `sharetimes` | string | `"0"` | 分享次数 |
| `attachment` | string | `"0"` | 附件标记 |
| `closed` | string | `"0"` | `"1"` = 帖子已关闭 |
| `hidden` | string | `"0"` | 隐藏标记 |
| `status` | string | `"32"` | 帖子状态位 |
| `highlight` | string | `"0"` | 高亮标记 |
| `stamp` | string | `"-1"` | 印章 ID |
| `icon` | string | `"-1"` | 图标 ID |
| `replycredit` | string | `"0"` | 回复奖励 |
| `ordertype` | string | `"0"` | 排序类型 |
| `relay` | string | `"0"` | 转发数 |
| `recommend` | string | `"0"` | 推荐标记 |
| `comments` | string | `"0"` | 评论数 |
| `moderated` | string | `"0"` | 是否被管理操作 |
| `isgroup` | string | `"0"` | 是否为群组帖子 |

### `postlist` — 回复列表（核心）

> **坑点**：与 `forumdisplay` 一样，`dateline` 是日期字符串，`dbdateline` 才是 Unix 时间戳。

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
| `message` | string | — | 回复内容（**含 HTML 标签**） |
| `number` | string | `"1"` | ✅ **楼层号**（`"1"` = 楼主，`"2"`+ = 回复） |
| `position` | string | `"1"` | 位置号（通常同 `number`） |
| `groupid` | string | `"30"` | 用户组 ID |
| `groupiconid` | string | `"6"` | 用户组图标 ID |
| `adminid` | string | `"0"` | 管理员 ID |
| `attachment` | string | `"0"` | 附件标记 |
| `anonymous` | string | `"0"` | `"1"` = 匿名回复 |
| `status` | string | `"0"` | 状态 |
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
- GET: 获取 `formhash`
- POST: 提交登录表单

POST 字段：

| 字段 | 说明 |
|------|------|
| `formhash` | CSRF token |
| `fastloginfield` | 固定 `"username"` |
| `username` | 用户名 |
| `password` | 密码 |
| `questionid` | `"0"` |
| `answer` | `""` |
| `cookietime` | `"2592000"`（30天） |

响应 `Message.messageval`：
- `"login_succeed"` → 登录成功
- 其他 → 登录失败，`messagestr` 为错误信息

---

## module=sendpost（发回复）

请求参数（POST）：

| 字段 | 说明 |
|------|------|
| `fid` | 版块 ID |
| `tid` | 帖子 ID |
| `message` | 回复内容 |
| `posttime` | 当前 Unix 时间戳 |

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
| `credits` | string | `"147030"` | 总积分 |
| `posts` | string | `"2039"` | 发帖数 |
| `threads` | string | `"4"` | 主题数 |
| `digestposts` | string | `"0"` | 精华帖数 |
| `friends` | string | `"0"` | 好友数 |
| `follower` | string | `"3"` | 粉丝数 |
| `following` | string | `"0"` | 关注数 |
| `newfollower` | string | `"3"` | 新粉丝数 |
| `blacklist` | string | `"12"` | 黑名单人数 |
| `oltime` | string | `"14703"` | 在线时长（小时） |
| `views` | string | `"0"` | 空间被访问数 |
| `lastvisit` | string | `"2026-7-8 13:32"` | 最后访问时间 |
| `lastactivity` | string | `"2026-7-8 10:54"` | 最后活跃时间 |
| `lastpost` | string | `"2026-7-1 08:59"` | 最后发帖时间 |
| `gender` | string | `"0"` | `"0"` = 保密，`"1"` = 男，`"2"` = 女 |
| `site` | string | — | 个人网站 |
| `bio` | string | — | 个人简介 |
| `interest` | string | — | 兴趣爱好 |
| `recentnote` | string | — | 最近状态/签名 |
| `spacenote` | string | — | 空间公告 |
| `self` | string | `"1"` | `"1"` = 查看自己的资料 |
| `attachsize` | string | `"   0 B "` | 附件总大小 |
| `todayattachs` | string | `"0"` | 今日上传附件数 |
| `extcredits1` | string | `"84"` | 扩展积分1（战斗力/鹅） |
| `extcredits5` | string | `"3207"` | 扩展积分5（死鱼/条） |

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

### `extcredits` — 扩展积分配置

以 `extcredits` ID 为 key，每项包含 `title`（名称）、`unit`（单位）、`ratio`（兑换比率）。

### `space.privacy` — 隐私设置

包含 `feed`（动态）、`view`（查看）、`profile`（资料字段）的隐私级别映射。

---

## module=sendpm（发私信）

> 未实现。`ApiConfig.moduleSendMessage` 已定义但无调用代码。

---

## 已知陷阱

1. **`dateline` ≠ 时间戳**：帖子列表中 `dateline` 是 `"YYYY-M-D H:mm"` 格式字符串，必须用 `dbdateline`（Unix 秒）作为时间戳
2. **所有数值字段均为字符串**：`views`、`replies`、`tid` 等都需要 `int.tryParse`
3. **`typename` 不在帖子列表中**：需通过 `typeid` 查 `threadtypes.types` 映射表
4. **`message` 字段截断**：帖子列表中的 `message` 是正文摘要，非完整内容
5. **`ppp`（每页帖数）各不相同**：`forumdisplay` 用 `tpp=50` 算帖子列表页数，`viewthread` 用 `ppp=40` 算帖子详情页数，代码中不能混用或硬编码
6. **CORS 限制**：Web 端需通过代理服务器访问 API
