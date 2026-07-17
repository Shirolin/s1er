# Sentry 崩溃监控设置

S1er 使用 [Sentry](https://sentry.io/) 收集运行时的崩溃与错误信息。Sentry 默认不启用，需要通过 `--dart-define` 注入 DSN 才能激活。

## 1. 注册 Sentry 账号

1. 打开 [sentry.io](https://sentry.io/signup/)，用 GitHub / Google 账号登录（免费版每月 5k 事件，个人项目完全够用）
2. 登录后创建新项目，平台选 **Flutter**
3. 记下给你的 **DSN**，长这样：
   ```
   https://abc123def456@sentry.io/1234567
   ```

## 2. 本地开发/构建时注入 DSN

### Web 开发

```bash
flutter run -d chrome --dart-define=SENTRY_DSN=https://abc123def456@sentry.io/1234567
```

### Android 构建

```bash
flutter build apk --release --dart-define=SENTRY_DSN=https://abc123def456@sentry.io/1234567
```

### 所有平台通用

添加 `--dart-define=SENTRY_DSN=...` 到构建命令即可。

## 3. 验证是否生效

1. 在 Sentry Flutter 初始化完成后，Sentry 会自动捕获未处理的 Flutter 错误和 Dart 异常
2. 可以在 Sentry 项目 Dashboard -> Issues 中查看上报的错误
3. 如果 DSN 为空（未注入），Sentry 不会初始化，不影响 App 正常运行

## 4. 安全注意事项

- **DSN 是公开可见的**（包含在客户端代码中），但只有你 Sentry 账号下的项目能接收该 DSN 上报的事件
- **不要在 `env_config.dart` 中硬编码 DSN**，务必通过 `--dart-define` 在编译时注入
- 不要将包含 DSN 的构建命令提交到 Git 历史中

## 5. 禁用 Sentry

去掉 `--dart-define=SENTRY_DSN=...` 参数重新编译即可，运行时 `EnvConfig.sentryEnabled` 会返回 `false`。
