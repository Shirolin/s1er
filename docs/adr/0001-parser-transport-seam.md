# 0001. 解析（纯）与传输（I/O）分层：抽出 DiscuzParser

- 状态：已接受
- 日期：2026-10-06
- 相关：`docs/agents/domain.md`、`lib/services/api_service.dart`、`lib/services/http_client.dart`

## 背景

`lib/services/api_service.dart` 有 4,002 行，其中仅约 71 行含 `await`（约 3%）。也就是说近 98% 的内容是纯解析逻辑——帖子、主题、私信、通知、收藏、搜索、用户空间、表单与提交响应——却被少数传输方法拖着，和 `dio`、`http_client.dart`、`talker.dart` 一起挤在同一个 `class ApiService` 里。

后果：

- 想测任一解析器，测试必须 import 整个 4,002 行的服务（连带 `dio`）。
- provider 越过接口直调其静态解析方法（如 `lib/providers/post_provider.dart:216` 的 `ApiService.parsePostListAsync`）。
- 团队已手工在服务上打洞以让解析可测：`parseSpaceReplyHtmlForTest`（第 2074 行）就是纯为暴露 `_parseReplyHtml` 而开的口子——说明接缝本就存在，只是画错了位置。

解析器的真实依赖是干净的：只依赖 `models/*` 与少数纯 utils（`discuz_message`、`discuz_submit_response`、`new_thread_form_parser`、`forum_attachment_upload_info_parser`、`compose_img_tags`）。唯一杂质是 `rescueJsonFromHtml` 中的一处 `talker.warning`。

## 决策

1. **抽出独立的 `DiscuzParser` 模块**，承载全部返回模型/数据的纯解析方法（JSON 解析与 HTML 抓取）。调用点与测试统一从 `DiscuzParser.parseX(...)` 进入。
2. **`DiscuzParser` 保持纯 Dart，不引入 Flutter 依赖。** 它可依赖 `models/*`、纯 utils 与 `talker`（全局日志单例，非 UI 依赖）。
3. **`parsePostListAsync`（`compute`）留在 `ApiService`。** `compute` 是平台能力（Web 同步 / native isolate），属于传输层；它只是转调 `DiscuzParser.parsePostList`，调用点 `post_provider.dart:216` 几乎不动。
4. **协议策略留在 `ApiService`**：`buildApiUrl`、`extractMaintenanceMessage`、`isLoginRequiredResponse`、`checkAuthError` 不搬。它们是"协议判定/编排"，不是"数据解析"。
5. **`rescueJsonFromHtml` 连同其 `talker.warning` 一并搬入 `DiscuzParser`。** 保持日志行为不变，不为其改签名。
6. **删除 `parseSpaceReplyHtmlForTest`** 等测试专用桩；接缝暴露后测试直接从 `DiscuzParser` 调。
7. **分两步执行**：第一步是零行为变更的机械搬移（测试全绿），第二步再视需要做模块内部按域分簇。

## 结果

**已完成（2026-10-06）：**

- `ApiService`：**4,002 → 1,806 行**（仅剩传输 + 协议策略）。
- 新建 `lib/services/discuz_parser.dart`（约 1,960 行，纯 Dart，零 Flutter/Dio 依赖，isolate 安全）。
- 9 个测试文件 + 2 个 provider 改为直接调用 `DiscuzParser`；`ApiService` 的纯委托 stub 与 `parseSpaceReplyHtmlForTest` 手工桩已删除。
- `UserSpaceListResult` 值类型从 `api_service.dart` 迁至 `lib/models/user_space_item.dart`。
- 校验：`flutter analyze`（lib + test）无 issue；`flutter test` 全绿。
- 保留在 `ApiService`：`ensureJson`（协议策略）、`extractMaintenanceMessage`、`checkAuthError`、`isLoginRequiredResponse`、`_unwrapAjaxHtml`、`parsePostListAsync` 的 `compute` 外壳。

正面：

- 局部性：抓取/解析类 bug 与其测试同处，测试 import 从 4,000 行降到约 1,960 行的纯模块。
- 接缝收敛：provider 与测试跨同一个 `DiscuzParser` 接口，不再越过 `ApiService` 直调静态方法。
- `ApiService` 接口收窄为传输职责；删除为测试而开的手工洞。

负面 / 代价：

- 一次跨 4,000 行文件的大范围机械搬移，已保证零行为变更（每步 analyze + 全量测试护栏）。
- `DiscuzParser` 暂为单模块；若继续膨胀，按第 7 条的第二步在模块内按域分簇（`part` / 分组静态类）。

## 备选方案

- **只抽最痛的 HTML 抓取簇**（搜索/收藏/用户空间），JSON 解析留在原地：解决不了根问题，接缝仍然模糊。
- **一开始就切成多个独立顶层模块**（`PostParser`、`PmParser`、`SearchParser`）：局部性更细，但调用点 import 分散、迁移面变大；留待第二步按需演进。
- **把 `compute` 也移进模块**：会迫使纯 Dart 模块拖入 `flutter/foundation`，破坏最大收益，已否决。
