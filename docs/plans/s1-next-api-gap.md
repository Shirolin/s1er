# S1-Next 接口对照

> 对照源：[S1-Next](https://github.com/ykrank/S1-Next) `master` @ `20a14fdb43`（`alpha 3.3.95`；最近标签 `v3.0.87-alpha`）  
> 读取文件：`S1Service` / `ApiForum` / `ApiHome` / `ApiMember` / `AppService`  
> 我方以 `lib/services/api_service.dart` + `lib/services/forum_tools_service.dart` + `lib/config/api_config.dart` + [`docs/api_reference.md`](../api_reference.md) 为准  
> 上次更新：2026-07-15（好友列表、手动每日签到、小黑屋、楼层举报）

对话旁的 Cursor Canvas 副本在本机：
`~/.cursor/projects/d-Project-s1-app/canvases/s1-next-api-gap.canvas.tsx`  
（**不进 git**；以本文档为项目内权威版本。Canvas 可能过期，勿单独当真相源。）

## 摘要

| 状态 | 含义 | 条数 |
|------|------|------|
| 已实现 | Discuz 能力功能等价（路径可不同） | 26 |
| 部分 | 有替代路径但不完整 | 0 |
| 未实现 | 无客户端能力 | 3 |
| 不做/边缘 | 可不跟 | 1 + App API 整组 |

计数口径：下表「Discuz 接口全表」每一行算 1 条（不含 App API 子表）。「收藏版块」属我方多出的已实现项。

### 两套后端

S1-Next 同时打 Discuz Mobile / `forum.php`，以及独立 App API（`https://app.saraba1st.com/2b/api/app/`）。  
我们只走 Discuz（`stage1st.com`），**App API 整组不做**。

## 优先缺口

| 能力 | S1-Next | 我们 | 说明 |
|------|---------|------|------|
| 私信会话详情 | `mypm&subop=view` | 应用内会话页 + 分页；网页兜底入口 | 已实现（登录态只读实测 + fixture） |
| 提醒/通知 | `module=mynotelist`（含系统提醒） | v3 JSON 双分类 + 同分类 HTML 兜底 | 已实现（两类登录态实测 + fixture） |
| 好友列表 | `module=friend` | `/friends` + 资料统计入口 | 已实现（合成 fixture；登录态列表待一次复核） |
| 每日签到 | `study_daily_attendance…` | 资料页手动签到卡 | 已实现（手动触发；自动签到后置） |
| 小黑屋 | `forum.php showdarkroom ajax` | `/dark-room` cursor 分页 | 已实现（公开只读实测 + fixture） |
| 发新主题 | `module=newthread` + 预取页面 | 新主题编辑器 + 只读权限预检 + 单次提交 | 已实现；真实写入未验证 |
| 发私信 | `module=sendpm` | `ApiConfig.moduleSendMessage` 仅常量 | docs 实测可用；UI/调用未接 |
| 编辑帖子 | `forum.php action=edit` | — | Mobile `editpost` 禁用，只能走 Web |
| 举报 | `misc.php?mod=report` | 举报弹窗 + `fetchReportForm` / `submitReport` | 已实现 |
| 服务端黑名单 | `home.php friend&view=blacklist` | 不同步网页黑名单 | 周边 |
| 本地黑名单 | 本地库 hide/del | Drift + `/blacklist` UI；`thread`/`post`/`pm` 均生效 | 已实现 |

## Discuz 接口全表

| 能力 | S1-Next 端点 | 我们 | 状态 |
|------|--------------|------|------|
| 版块首页 | `module=forumindex` | `getForumList()` → `forumindex` | 已实现 |
| 帖子列表 | `module=forumdisplay`（含 `typeid`） | `getThreadList(Raw)`；分类映射、筛选及分类内分页 | 已实现 |
| 帖子详情 | `viewthread` v1/`URL_POST_LIST_NEW` v4（含 `authorid`） | `getThreadDetail` v4 + `authorId`；楼内「只看该作者」已接 | 已实现 |
| 登录（含安全提问） | `module=login` | `login()` + 安全提问 | 已实现 |
| 刷新 formhash | `module=toplist` | viewthread / forumindex / login 响应提取 | 已实现（路径不同，等价） |
| 回复 | `module=sendreply` | `sendReply()` → `module=sendreply` | 已实现（2026-07 对齐；旧 `forum.php` reply 仅 `@Deprecated` 遗留） |
| 引用回复助手 | `forum.php action=reply` (quote helper) | `fetchQuoteInfo()` + `noticetrimstr` | 已实现 |
| 回复插图（外链图床） | `p.sda1.dev upload_external_noform` | `ExternalImageUploadService`（Web 经 `/ext-upload`） | 已实现 |
| 麻将脸表情 | 本地 assets + 实体码 | `assets/emoticons` + `ComposeEmoticonPanel` | 已实现 |
| 定位楼层页码 | `forum.php redirect=findpost` | `locatePostPage()` | 已实现 |
| 发新主题 | `module=newthread` + 预取页面 | `fetchNewThreadForm()` / `submitNewThread()` + `/forum/:fid/new-thread` | 已实现；匿名 GET 可见分类但无权限，禁止使用真实账号做写入验证 |
| 编辑帖子 | `forum.php action=edit` | — | 未实现 |
| 搜索（版块/用户） | `search.php mod=forum\|user` | `searchForum()` / `searchUser()` + 搜索 Tab | 已实现 |
| 投票 | `forum.php action=votepoll` | `votePoll()` | 已实现 |
| 评分 / 评分日志 | `action=rate` + `viewratings` | `fetchRateForm` / `submitRate` / `RateLogService` | 已实现 |
| 举报 | `misc.php?mod=report` | `fetchReportForm` / `submitReport` + 举报弹窗 | 已实现 |
| 收藏主题 增删查 | `myfavthread` / `favthread` | 查：JSON `myfavthread` + HTML；增删：`home.php` HTML（非 Mobile `favthread`） | 已实现 |
| 收藏版块 | —（S1-Next 仅主题） | `myfavforum` + HTML 增删 | 已实现（我们多出） |
| 私信会话列表 | `module=mypm` | `getPmList()` JSON + HTML 兜底 | 已实现 |
| 私信会话详情 | `mypm&subop=view` | `getPmConversation()` + 应用内会话页 | 已实现 |
| 发私信 | `module=sendpm` | 常量预留，无 Service/UI | 未实现 |
| 提醒/通知 | `mynotelist`（mypost + system） | v3 JSON 优先 + 同分类 HTML 兜底 | 已实现 |
| 用户资料 | `module=profile`（另有 profile Web） | `getUserProfile` / `getUserProfileByUid` | 已实现 |
| 好友列表 | `module=friend`（`version=1`） | `ForumToolsService.getFriendList` + `/friends` | 已实现 |
| 用户主题/回复 | `home.php space thread/reply` | `getUserSpaceList` / `getMySpaceList` | 已实现 |
| 每日签到 | `study_daily_attendance…` GET + formhash | 资料页手动签到（`dailySign`） | 已实现 |
| 小黑屋 | `forum.php showdarkroom ajaxdata=json` | `getDarkRoom` + `/dark-room` cursor | 已实现 |
| 服务端黑名单 | `home.php friend&view=blacklist` | —（不同步网页黑名单） | 未实现 |
| 本地黑名单 | 本地库 hide/del | Drift + `/blacklist`；`thread` 滤列表、`post` 折叠楼层、`pm` 隐藏会话；备份 `blacklist.json` | 已实现 |
| 交易贴信息 | `viewthread&do=tradeinfo` | — | 不做/边缘 |

## S1-Next App API（跳过）

基址：`https://app.saraba1st.com/2b/api/app/`（`AppApi.BASE_URL`）

| 能力 | S1-Next | 我们 |
|------|---------|------|
| App 用户信息 / 登录 / 签到 | `user` / `user/login` / `user/sign` | 不使用 |
| App 帖子分页 / 帖信息 | `thread/page` / `thread` | 不使用（走 Discuz `viewthread`） |
| App 投票读/写 | `poll/poll` / `poll/options` / `poll/vote` | 不使用（走 Discuz `votepoll`） |

## 建议落地顺序

1. **只读/本地**  
   ~~搜索~~、~~私信会话详情~~、~~通知 JSON~~、~~好友列表~~、~~小黑屋~~ 与本地 `pm` 黑名单均已落地；服务端黑名单同步仍后置。
2. **写操作（等论坛稳定后再开）**  
   发新帖 `newthread` → 发私信 `sendpm` → 编辑 / 举报  
   （手动 Discuz 签到已落地；自动签到为后续 opt-in。）
3. **剩余社交周边**  
   服务端黑名单同步

## 实现差异备注

- **回复端点**：已与 S1-Next 对齐为 `module=sendreply`；旧 `forum.php` reply 仅作遗留对照（`sendPost` `@Deprecated`）。
- **搜索**：对齐 `search.php` HTML；主题结果结构化提取（非整段 HTML 渲染）；客户端 30s 提交冷却。
- **收藏**：他们查 `myfavthread`、增删偏 Mobile `favthread`；我们查 JSON + HTML 兜底，增删主路径是 `home.php`，并多了收藏版块。
- **通知**：对齐 `mynotelist` v3（帖内提醒 + 系统提醒分接口），同分类 notice HTML 保留为兼容兜底；登录态两类实测已通过。
- **私信详情**：对齐 `mypm&subop=view` 并应用内展示；登录态只读实测已通过；`sendpm` 仍未实现。
- **好友列表**：Mobile `module=friend&version=1&uid=`；响应 `Variables.list[{uid,username}]`；无可靠分页，MVP 单次加载。
- **每日签到**：Discuz 插件 GET（非 App API `user/sign`）；显式点击；`formhash` 放入 query；解析 `succeedhandle_*` / `errorhandle_*`。
- **小黑屋**：公开 `ajaxdata=json`；`data` 可为 Map/List；下一 cursor 取自 `message` 的 `dataexist|cid`，不能用末项 `cid`。
- **forumdisplay `typeid`**：请求使用 `filter=typeid&typeid=...&tpp=50`，分类切换与分页已接入。
- **登出**：双方都是清 Cookie/会话，无独立 Discuz logout module 依赖。
- **本地黑名单**：设备级（主键被拉黑 `uid`）；`scope`=`thread`/`post`/`pm`；楼层默认折叠可展开，PM 会话隐藏；与 `blacklist.json` 备份往返兼容。不接网页好友黑名单同步。
- **死常量**：`ApiConfig.moduleSendMessage` / `moduleFavThread` / `moduleFavForum` 已声明；`moduleSendMessage` 接 `sendpm`、或切 Mobile 收藏时复用 `moduleFav*`。
