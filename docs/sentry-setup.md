# Sentry 崩溃监控设置

S1er 使用 [Sentry](https://sentry.io/) 收集运行时的**未处理崩溃与启动失败**。Sentry **默认不启用**，需通过 `--dart-define` 注入 DSN。

实现入口：`lib/services/sentry_bootstrap.dart`（过滤策略见 `sentry_event_filter.dart`）。

## 上报边界

| 上报 | 不上报 |
|:---|:---|
| 未捕获的 Flutter / Dart 异常（Native；Web 经链式 handler） | 已 catch 的业务/网络错误（Talker + 友好文案） |
| `main` 初始化失败（DB / Cookie / HTTP 启动链） | 单张图片加载/解码失败 |
| 其它编程错误（经 `beforeSend` 放行） | Web `ViewInsets cannot be negative` 噪声 |
| | Debug 构建默认丢弃（除非 `SENTRY_DEBUG_UPLOAD=true`） |

**Performance**：默认 `SENTRY_TRACES_SAMPLE_RATE=0`（不开性能采样）。不把 Talker 全量同步到 Sentry。

## 1. 注册 Sentry 账号

1. 打开 [sentry.io](https://sentry.io/signup/)，用 GitHub / Google 账号登录（免费版每月 5k 事件，个人项目完全够用）
2. 登录后创建新项目，平台选 **Flutter**
3. 记下给你的 **DSN**，长这样：
   ```
   https://abc123def456@sentry.io/1234567
   ```

## 2. 注入 DSN（推荐仅 release）

### Release 构建（推荐）

```bash
flutter build apk --release --dart-define=SENTRY_DSN=https://abc123def456@sentry.io/1234567
```

### 本地 Debug 验证（需显式允许上传）

```bash
flutter run -d chrome \
  --dart-define=SENTRY_DSN=https://abc123def456@sentry.io/1234567 \
  --dart-define=SENTRY_DEBUG_UPLOAD=true
```

未设 `SENTRY_DEBUG_UPLOAD=true` 时，debug 事件会在 `beforeSend` 被丢弃，避免本机误开 DSN 刷配额。

### 可选：性能采样

```bash
--dart-define=SENTRY_TRACES_SAMPLE_RATE=0.2
```

默认 `0`。仅在明确需要 Performance 时打开。

### 脚本（`scripts/build.ps1` / `start_dev.ps1`）

须通过环境变量 **显式** 设置 `S1_SENTRY_DSN`；未设置时脚本**不会**注入 DSN。不要把 DSN 写进仓库。

| `--dart-define` | 默认 | 说明 |
|:---|:---|:---|
| `SENTRY_DSN` | 空 | 非空启用 Sentry |
| `SENTRY_TRACES_SAMPLE_RATE` | `0` | 0–1；性能采样 |
| `SENTRY_DEBUG_UPLOAD` | `false` | debug 是否实际上传 |

## 3. 验证是否生效

1. Release（或 Debug + `SENTRY_DEBUG_UPLOAD`）注入 DSN 后启动
2. 故意触发未捕获异常，或制造启动失败，在 Sentry Issues 中应看到事件（带 `environment` / `release`）
3. 断网刷帖、登录失败、坏图打开查看器：**不应**新增 Issue
4. DSN 为空时不初始化，不影响正常运行

## 4. 安全注意事项

- **DSN 是公开可见的**（包含在客户端代码中），但只有你 Sentry 账号下的项目能接收该 DSN 上报的事件
- **不要在 `env_config.dart` 中硬编码 DSN**，务必通过 `--dart-define` 在编译时注入
- **不要将包含真实 DSN 的构建命令提交到 Git 历史**
- `sendDefaultPii` 保持关闭

## 5. 禁用 Sentry

去掉 `--dart-define=SENTRY_DSN=...` 重新编译即可；`EnvConfig.sentryEnabled` 为 `false`。
