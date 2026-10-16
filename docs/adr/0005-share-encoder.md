# 0005. 分享卡编码独立为 ShareEncoder

- 状态：已接受
- 日期：2026-10-07
- 相关：`lib/utils/share_encoder.dart`、`lib/services/post_share_service.dart`
- 取代：`lib/services/share_browser_image_encode_*`（迁至 `lib/utils/`）

## 背景

分享卡的捕获 / 拼接 / 编码整条流水线原以方法形式挂在
`_SharePreviewSheetState`（`ConsumerStatefulWidget`）上。核对后分两类：

- **编码原语早已在 utils**（`encodeSharePngOptimized` / `encodeShareJpegFromPng` /
  `encodeShareWebpFromPng` / `encodePngFromRgbaStrip` / `flattenRgbaOntoOpaqueRgbaAsync`
  / 浏览器 canvas 编码）。
- **留在 sheet 的是编排**：格式分派、三条**降级链**（native 编码失败→PNG）、
  以及背景压平。其中唯一的 `BuildContext` 依赖是背景色 `Theme.of(context)`
  → `S1Surface.card(scheme)`。
- **捕获 / 拼接**（`_captureBytes` / `_captureFullCardScrollStrips` /
  `_captureChunkedAndEncode` / `_captureFromRepaint`）是 render-bound
  （`RenderRepaintBoundary` / 滚动控制器 / `setState` / `mounted`），不可轻抽。

## 决策

1. **抽出 `ShareEncoder`**（`lib/utils/`）：吸收格式分派 + 三条降级链 + 背景
   压平。接口为 `ShareEncoder({required ShareImageFormat format, required Color
   background})` 与 `encodeImage(ui.Image)` / `encodeStrip(ShareRgbaStrip)`。
2. **背景色由调用方解析**：sheet 从主题取出 `S1Surface.card(scheme)` 传入，
   编码器不依赖 Theme / Material / Riverpod / widget。
3. **`_EncodedShareImage` 提为公开 `EncodedShareImage`**，随编码器落地。
4. **捕获 / 拼接留在 sheet**：render-bound，抽离需为渲染副作用造抽象，风险
   远超收益。
5. **浏览器编码迁至 `lib/utils/`**：原在 `lib/services/`，被即将落在 utils 的
   编码器引用会造成 utils→services 反向依赖；其为纯编码原语，归 utils 更符合
   分层。
6. **零行为变更**：降级链逐字保留。

7. **预览 sheet 与分享服务共置（有意保留）**：`_SharePreviewSheet` 留在 `lib/services/post_share_service.dart`，不迁往 `lib/widgets/`。搬移任一方向都会踩线：sheet 依赖 `talker` 诊断日志（`widgets/` 禁止 import `services/`，见 `test/architecture/guardrails_test.dart`），而把 `share()` 入口搬到 widgets 则要求 provider→widgets import（全仓无先例）；且捕获 / 预览 / 落盘是同一分享生命周期的 render-bound 部分（见决策 4）。服务其余部分已保持纯净（编码器见本 ADR），sheet 共置视为 documented exception（同 ADR-0008「承重透传」先例）。

## 结果

正面：

- 局部性：编码策略（含降级链）集中在一处，可脱离 widget 测试。
- 接缝不再跨越 UI：编码器不碰 context / ref。
- 补上了原本缺失的降级链测试面（`share_encoder_test.dart`：PNG 直出、JPEG/WebP
  的 native-成功或降级两条路径、`EncodedShareImage` 派生属性）。

负面 / 代价：

- 浏览器编码文件位置变更（`lib/services/` → `lib/utils/`），仅 `share_encoder.dart`
  引用。
- 捕获 / 拼接仍是 sheet 方法（有意保留，见决策 4）；预览 sheet 与服务共置（有意保留，见决策 7）。

## 备选方案

- **连捕获 / 拼接一并抽出**：需为 `RenderRepaintBoundary`、滚动控制器、
  `setState`、`mounted` 造抽象层，复杂度远超收益。已否决。
- **只抽两个背景压平方法**：降级链仍散落 sheet，接缝未建立。已否决。
- **`ShareEncoder` 落在 `lib/services/`**：可避免 utils→services 依赖，但它是
  纯编码编排、无 I/O，归 `lib/utils/` 更贴切；改为把浏览器编码一并迁至 utils。
