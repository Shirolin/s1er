# 应用升级清单

客户端通过 `EnvConfig.updateManifestUrl`（默认本目录 `latest.json` 的 GitHub raw URL）拉取版本信息，用于应用内升级提醒。

## 发版时

1. 打 GitHub Release（附各平台安装包，如有）。
2. 更新 [`latest.json`](latest.json)：
   - `latest`：与 `pubspec.yaml` 的 version **名**一致（如 `1.2.0`，不含 `+build`）
   - `notes`：面向用户的更新说明（可空）
   - `publishedAt`：发布日（`YYYY-MM-DD`）
   - `channels.*`：有直链则填，否则保持 `null`（客户端回退 `github`）
3. 需要踢掉过旧安装包时，抬高 `minSupported`（低于该版本每次冷启动强提醒，可关但下次仍弹）。
4. 将改动提交到 `main`（raw URL 指向 main）。

## 本地覆盖

```bash
flutter run --dart-define=UPDATE_MANIFEST_URL=https://example.com/latest.json
flutter run --dart-define=DISTRIBUTION=play
```
