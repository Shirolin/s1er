# S1-Next 接口对照

> 对照源：[S1-Next](https://github.com/ykrank/S1-Next) `v3.0.87-alpha` 的 `S1Service` / `ApiForum` / `ApiHome` / `ApiMember`  
> 我方以 `lib/services/api_service.dart` + [`docs/api_reference.md`](../api_reference.md) 为准  
> 上次更新：2026-07-14

对话旁的 Cursor Canvas 副本在本机：
`~/.cursor/projects/d-Project-s1-app/canvases/s1-next-api-gap.canvas.tsx`  
（**不进 git**；以本文档为项目内权威版本。）

## 摘要

| 状态 | 含义 | 约数 |
|------|------|------|
| 已实现 | 功能等价 | 17 |
| 部分 | 有替代路径但不完整 | 2 |
| 未实现 | 无客户端能力 | 8 |
| 不做/边缘 | 可不跟 | 1 + App API 整组 |

### 两套后端

S1-Next 同时打 Discuz Mobile / `forum.php`，以及独立 App API（`https://app.saraba1st.com/2b/api/app/`）。  
我们只走 Discuz（`stage1st.com`），**App API 整组不做**。

## 优先缺口

| 能力 | S1-Next | 我们 | 说明 |
|------|---------|------|------|
| 发新主题 | `module=newthread` + 预取页面 | — | docs 实测可用；写操作暂缓 |
| 编辑帖子 | `forum.php action=edit` | — | Mobile `editpost` 禁用，只能走 Web |
| 搜索（版块/用户） | `search.php mod=forum\|user` | — | 适合只读阶段 |
| 举报 | `misc.php?mod=report` | — | 次常用写操作 |
| 发私信 | `module=sendpm` | — | docs 实测可用 |
| 好友列表 | `module=friend` | 仅 friends 计数 | 周边 |
| 每日签到 | `study_daily_attendance…` | — | 周边 |
| 小黑屋 | `forum.php showdarkroom ajax` | — | 周边 |
| 服务端黑名单 | `home.php friend&view=blacklist` | 本地黑名单 MVP（无服务端同步） | 周边 |
| 本地黑名单 | 本地库 hide/del | UI + `thread`/`post` 过滤；`pm` 预留 | 部分 |
| 私信会话详情 | `mypm&subop=view` | 仅列表 / WebView 入口 | 部分 |
| 提醒/通知 | `module=mynotelist` | `home.php do=notice` HTML | 部分；未用 JSON |

## Discuz 接口全表

| 能力 | S1-Next 端点 | 我们 | 状态 |
|------|--------------|------|------|
| 版块首页 | `module=forumindex` | `forumindex` | 已实现 |
| 帖子列表 | `module=forumdisplay` | `forumdisplay` | 已实现 |
| 帖子详情 | `module=viewthread` (v1/v4) | `viewthread` v4 | 已实现 |
| 登录（含安全提问） | `module=login` | `login` | 已实现 |
| 刷新 formhash | `module=toplist` | viewthread / forumindex / login | 已实现（路径不同，等价） |
| 回复 | `module=sendreply` | `sendReply()` → `module=sendreply` | 已实现（2026-07 已对齐；旧 forum.php reply 仅遗留） |
| 引用回复助手 | `forum.php action=reply` (quote helper) | `fetchQuoteInfo()` + `noticetrimstr` | 已实现 |
| 回复插图（外链图床） | `p.sda1.dev upload_external_noform` | `ExternalImageUploadService`（Web 经 `/ext-upload`） | 已实现 |
| 麻将脸表情 | 本地 assets + 实体码 | `assets/emoticons` + `ComposeEmoticonPanel` | 已实现 |
| 定位楼层页码 | `forum.php redirect=findpost` | `locatePostPage()` | 已实现 |
| 发新主题 | `module=newthread` + 预取页面 | — | 未实现 |
| 编辑帖子 | `forum.php action=edit` | — | 未实现 |
| 搜索（版块/用户） | `search.php mod=forum\|user` | — | 未实现 |
| 投票 | `forum.php action=votepoll` | `votePoll()` | 已实现 |
| 评分 / 评分日志 | `action=rate` + `viewratings` | `fetchRateForm` / `submitRate` / RateLogService | 已实现 |
| 举报 | `misc.php?mod=report` | — | 未实现 |
| 收藏主题 增删查 | `myfavthread` / `favthread` | HTML `home.php` + JSON 兜底 | 已实现 |
| 收藏版块 | —（S1-Next 仅主题） | `myfavforum` + HTML | 已实现（我们多出） |
| 私信会话列表 | `module=mypm` | `mypm` + HTML 兜底 | 已实现 |
| 私信会话详情 | `mypm&subop=view` | —（仅列表 / WebView） | 部分 |
| 发私信 | `module=sendpm` | — | 未实现 |
| 提醒/通知 | `module=mynotelist` | `home.php do=notice` HTML | 部分 |
| 用户资料 | `module=profile` | `profile` | 已实现 |
| 好友列表 | `module=friend` | 仅展示 friends 计数 | 未实现 |
| 用户主题/回复 | `home.php space thread/reply` | `getUserSpaceList` / `getMySpaceList` | 已实现 |
| 每日签到 | `study_daily_attendance…` | — | 未实现 |
| 小黑屋 | `forum.php showdarkroom ajax` | — | 未实现 |
| 服务端黑名单 | `home.php friend&view=blacklist` | —（不同步网页黑名单） | 未实现 |
| 本地黑名单 | 本地库 hide/del | Drift + `/blacklist` UI；`thread` 滤列表、`post` 折叠楼层；`pm` 可存不筛 | 部分 |
| 交易贴信息 | `viewthread&do=tradeinfo` | — | 不做/边缘 |

## S1-Next App API（跳过）

| 能力 | S1-Next | 我们 |
|------|---------|------|
| App 用户信息 / 登录 / 签到 | `app.saraba1st.com …/user*` | 不使用 |
| App 帖子分页 / 投票 | `…/thread*`、`/poll*` | 不使用（走 Discuz） |

## 建议落地顺序

1. **只读/本地（适合 S1 繁忙或暂缓写操作时）**  
   搜索、私信会话详情、通知体验（本地黑名单 UI+过滤已部分落地）
2. **写操作（等论坛稳定后再开）**  
   发新帖 `newthread` → 发私信 `sendpm` → 编辑 / 举报
3. **社交周边（可后置）**  
   签到、好友列表、服务端黑名单同步、小黑屋

## 实现差异备注

- **回复端点**：已与 S1-Next 对齐为 `module=sendreply`；旧 `forum.php` reply 仅作遗留对照。
- **收藏**：他们偏 Mobile `favthread`；我们主路径是 `home.php` HTML，并多了收藏版块。
- **通知**：他们用 `mynotelist` JSON；我们用 notice HTML 列表（可读已可用）。
- **登出**：双方都是清 Cookie/会话，无独立 Discuz logout module 依赖。
- **本地黑名单**：设备级（主键为被拉黑 `uid`）；`scope`=`thread`/`post`/`pm`（`pm` 预留）；楼层默认折叠可展开，非硬删；与 `blacklist.json` 备份往返兼容。不接网页好友黑名单同步。
