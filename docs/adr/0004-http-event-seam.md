# 0004. HTTP 客户端通知依赖反转：事件出、适配器落库

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/services/http_client.dart`、`lib/services/s1_http_event.dart`、`lib/providers/http_event_bridge_provider.dart`、`lib/main.dart`

## 背景

`S1HttpClient` 通过 `_read<T>(ProviderListenable<T>)`（双路分派到 `_ref` 或 `_testContainer`）直接读写三个 provider：

- `formhashProvider`（读 + 写）：请求前注入 formhash；从响应 / HTML 提取后更新。
- `unreadCountProvider`（写）：从响应 `Variables.notice` 更新未读。
- `serverNoticeProvider`（写）：从响应 / 错误体喂官方公告。

一个 **service 直接驱动 provider 状态**，`_read` 的双路分派即该耦合的信号：模块需要一整张 provider 图才能工作。

## 决策

1. **只反转两个纯通知写依赖**（`unreadCountProvider` / `serverNoticeProvider`）：`S1HttpClient` 新增广播事件流 `events`（`Stream<S1HttpEvent>`），响应 / 错误时发出 `S1UnreadNoticeEvent` / `S1ServerNoticeEvent`，**不再 import 这两个 provider**。
2. **provider 层适配器 `httpEventBridgeProvider`** 订阅 `events`，把事件分发到两个 notifier（`updateFromNotice` / `offer`）。订阅随容器销毁取消；`main.dart` 启动时读取一次以建立订阅。
3. **`formhashProvider` 保留**（不进事件流）：它是**请求协作状态**——客户端必须在发请求前**同步读到** formhash，且要能 `clear` / force 重取；其生命周期与 HTTP 请求强绑定。反转它会让 formhash 语义复杂化，收益不足。`_read` 因此只服务 `formhashProvider`。
4. **`unreadNoticeFromResponse` 提为纯静态**：响应体 → `S1UnreadNoticeEvent?` 的派生逻辑独立可测，拦截器只负责调用与转发。
5. **零行为变更**：事件时序与原来"响应后更新 notifier"一致（同步发出，异步送达）。

6. **测试投递口有意保留**：`debugEmit` / `dispose`（`@visibleForTesting`）是桥适配器测试的投递与清理口；生产路径仍由拦截器发出事件。测试直接构造事件比复现真实 HTTP 更稳定：删的是生产代码为测试开的解析旁路（ADR-0001 决策 6），此处是测试对事件流边界的直接投递，不冲突。

## 结果

正面：

- 接缝方向正确：service 只观测与转发，provider 层适配器负责状态写入。
- `http_client.dart` 不再 import 任何 provider；`_read` 仅剩 formhash 用途。
- 事件派生与分发各有测试面（`unreadNoticeFromResponse` + 桥适配器）。

负面 / 代价：

- 多一个事件类型文件与一个桥 provider；`main.dart` 需显式建立订阅。
- 事件是 fire-and-forget，无背压（与原先直接调用 notifier 等价）。
- `formhashProvider` 仍是客户端对 provider 的引用（有意保留）。

## 备选方案

- **连 `formhashProvider` 一并反转**：会让 formhash 的同步读取 / force-clear 语义复杂化，且现有 formhash 测试需重写；收益低、风险高。已否决。
- **注入 `void Function(...)` 回调**（而非 Stream）：可行，但每个通知点需单独接线，且广播给多个订阅者时不如 Stream 自然。已否决。
- **不反转，仅记录技术债**：反向依赖会继续扩散（后续新增通知会照抄 `_read`）。已否决。
