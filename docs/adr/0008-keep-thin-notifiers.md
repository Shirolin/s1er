# 0008. forumListProvider 与 postShareProvider 保留（不删）

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/providers/forum_list_provider.dart`、`lib/providers/post_share_provider.dart`、`test/architecture/guardrails_test.dart`

## 背景

架构评审把两个「透传 notifier」列为可删：

- `forumListProvider`（21 行）：`build() => apiService.getForumList()` + `refresh()`。
- `postShareProvider`（16 行）：把参数转交给 `PostShareService.share`。

初判「interface ≈ implementation，deletion test = just moves」。但核对调用方后，
结论**相反**：两者的 implementation 薄，**接口是承重墙**。

## 决策：两个都保留

### `postShareProvider`——由机器强制的分层规则保护

- `thread_detail_screen.dart` 通过 `ref.read(postShareProvider.notifier)` 触发分享。
- `test/architecture/guardrails_test.dart` **强制**：`lib/screens/` 与 `lib/widgets/`
  不得 `import '../services/'`。
- 若删除该 provider 让屏幕直调 `PostShareService.share`，该 guardrails 测试直接失败。
  即：它是**分层规则要求存在的接缝**，不是可选仪式。

### `forumListProvider`——承载失效 / 刷新 / 测试注入

- `auth_provider.dart` 在登录 / 登出时 `ref.invalidate(forumListProvider)`
  （`:67`、`:116`）。
- `home_screen.dart` watch 它并调 `ref.read(forumListProvider.notifier).refresh()`
  （`:224`、`:335`、`:359`、`:365`）。
- `forum_name_provider.dart` 从中 `select`。
- **6 个测试文件**用 `ForumListNotifier` 子类 override 它以注入固定版块列表。

删除它会把「删除 + 失效 + 刷新 + 可注入」四处职责散到每个消费者
（deletion test 实为 **concentrates**，即应保留），而非「只是挪动代码」。

## 结果

- 保留两个 provider；**本轮无代码改动**。
- 记录本决策，避免将来的架构评审重复提出「删这两个透传 notifier」。

## 备选方案

- **删 `postShareProvider`，屏幕直调 service**：破坏 `guardrails_test` 的分层
  约束；需同时放宽规则，代价大于收益。已否决。
- **删 `forumListProvider`**：会破坏登录态失效、下拉刷新与 6 处测试注入。
  已否决。
- **「深化」`postShareProvider`**（加状态或缓存使其不再薄）：无真实需求，
  纯为消除「薄」而造状态，违 YAGNI。已否决。
