# 0009. 撰写草稿收进 ComposeSession，按 ComposeTarget 寻址

- 状态：已接受
- 日期：2026-11-07
- 相关：`lib/providers/compose_session_provider.dart`、`lib/models/compose_target.dart`、`lib/models/compose_draft.dart`、`lib/screens/compose_screen.dart`；取代 [ADR-0002](0002-draft-codec.md) 决策 2、4

## 背景

ADR-0002 让回复 / 新主题 / 编辑三个草稿类（`ComposeMessageDraft`、`NewThreadDraftStore`、`EditPostDraftStore`）保留各自的公开接口，理由是「调用点零改动」。

三者唯一的调用方是 `_ComposeScreenState`。屏幕为此写了 9 个按模式分开的读 / 存 / 清方法，外加 `_flushDraftForMode` / `_clearDraftForMode` 两处模式分派；每个方法都用 `try { … } on Object {}` 静默吞掉异常，注释称是为了「测试未注入 SettingsStore」，而所有渲染撰写页的测试其实都已注入。键规则、空草稿规则、回复防抖分散在三个类和屏幕之间。

## 决策

1. **新增 `ComposeTarget`**（`ReplyTarget` / `NewThreadTarget` / `EditPostTarget`）表示「写的是什么」，**`ComposeDraft`** 表示草稿内容。
2. **新增 `composeSessionProvider`**（`Provider.autoDispose.family`，按 `ComposeTarget` 取实例），`ComposeSession` 对外只有 `restoreDraft` / `saveDraft` / `clearDraft`。settings key、entry key、payload 形状、空草稿规则（回复：正文空；新主题：标题正文皆空；编辑：从不视为空）与回复防抖都在内部。
3. **回复防抖的未落盘写入在 provider 销毁时补写**，替代屏幕 `dispose` 里的手动 flush；`clearDraft` 同时丢弃未落盘写入。
4. **删除三个草稿类及其单测**；行为改由 `test/providers/compose_session_test.dart` 经 `ComposeSession` 接口验证，widget 测试直接读 settings 原始值来锁住落盘格式。
5. **落盘格式不变**：三个 settings key 与各自 payload 字段与 ADR-0002 时一致，已有草稿可直接恢复。`MapDraftCodec` 保留。

这是撰写页「深模块化」的第一步：`ComposeSession` 后续会接管提交、上传队列与编辑表单，届时演进为 `Notifier`。

## 结果

正面：

- 屏幕不再按模式分派草稿读写，离开对话框「放弃」只需 `clearDraft()`。
- 删除 9 处吞异常的 `try`。
- 草稿规则可脱离 widget 树测试。

负面 / 代价：

- 编辑草稿的「与加载基线相同则删除」仍由屏幕判断后调用 `clearDraft()`，因为基线目前还在屏幕里；编辑表单迁入 session 后再收进去。
- 「最近表情」仍在屏幕里直接读写 `SettingsStore`，不属于草稿，本次不动。

## 备选方案

- **保留三个草稿类，session 只做转发**：多一层且三类各只剩一个调用方，删除测试显示复杂度不会回流到多处，故并入。
- **按目标拆三个适配器类**：三种目标的差异只有键、payload 和空规则三处 `switch`，单一实现即可，不值得为此开接缝。
