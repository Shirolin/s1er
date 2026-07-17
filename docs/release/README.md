# 应用升级与版本管理

客户端通过 `EnvConfig.updateManifestUrl`（默认本目录 [`latest.json`](latest.json) 的 GitHub raw URL）拉取版本信息，用于应用内升级提醒。

## 版本号格式（`pubspec.yaml`）

```
version: 0.1.0+1
         ^^^^^  ^^
         name   build
```

| 部分 | 字段 | 关于页示例 | 作用 |
|:---|:---|:---|:---|
| **name** | `主.次.修订`（如 `0.1.0`） | `0.1.0` | 给用户看的产品版本；升级检查、`latest.json` 只比这一段 |
| **build** | `+` 后的整数（如 `+1`） | `(1)` | 每次打出安装包递增；Android `versionCode` / iOS `CFBundleVersion` |

应用内升级提醒**只比较 name**，忽略 `+build`。

### 当前约定：`0.x` = Beta

在公开承诺「稳定 1.0」之前，主版本保持 **`0`**：

- `0.1.0`、`0.1.1`、`0.2.0`… 均为 Beta
- 准备正式稳定后再切到 `1.0.0`（届时在 Release / `notes` 写清）
- **不要**把 beta 写进 name 后缀（如 `0.1.0-beta.1`）；当前比较逻辑会丢掉预发布后缀。宣传用语写在 GitHub Release 或 `notes` 即可

### 什么时候涨哪一位

| 改动 | 怎么涨 | 例子 |
|:---|:---|:---|
| 同版本连续打包（仅重打 / 热修安装包） | 只加 build | `0.1.0+1` → `0.1.0+2`（**不必**改 `latest.json`） |
| 修 bug、文案、小优化，希望用户感知「有新版本」 | 修订 `z+1` | `0.1.0` → `0.1.1` |
| 新功能、可见行为变化 | 次版本 `y+1`，`z` 归零 | `0.1.1` → `0.2.0` |
| 不兼容大改、大换皮（少见） | 主版本；Beta 期内一般仍留在 `0` | 稳定后才考虑 `1.0.0` |

每次对外发布安装包时，**build 必须比上一包大**。

## 发版清单

1. 改 [`pubspec.yaml`](../../pubspec.yaml) 的 `version`（name 与/或 build）。
2. 若 **name** 相对上一正式版有变化：更新 [`latest.json`](latest.json)
   - `latest`：与 name 一致（如 `0.2.0`，**不含** `+build`）
   - `notes`：面向用户的更新说明（可空；可写「Beta」）
   - `publishedAt`：发布日（`YYYY-MM-DD`）
   - `channels.*`：有直链则填，否则 `null`（客户端回退 `github`）
3. 需要踢掉过旧安装包时，抬高 `minSupported`（低于该版本每次冷启动强提醒，可关但下次仍弹）。仅抬 build、name 不变时一般不用动。
4. 打 GitHub Release（附各平台安装包，如有）；tag 建议与 name 对齐（如 `v0.1.0`）。
5. 将 `pubspec.yaml` + `latest.json` 等改动提交到 `main`（raw URL 指向 main）。

## 本地覆盖

```bash
flutter run --dart-define=UPDATE_MANIFEST_URL=https://example.com/latest.json
flutter run --dart-define=DISTRIBUTION=play
```
