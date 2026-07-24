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

1. **写更新内容**（构建之前！）：
   - [`CHANGELOG.md`](../../CHANGELOG.md)：新增 `[X.Y.Z]` section，按 Added / Changed / Fixed 分类
   - [`assets/changelog/whats_new.json`](../../assets/changelog/whats_new.json)：**顶部追加**该版本的用户向要点（3–8 条大白话；应用内「新功能」弹窗与设置「更新日志」读此文件，**不是** `CHANGELOG.md`）
   - [`docs/release/latest.json`](latest.json) 的 `notes`：一句话面向用户说明
2. 改 [`pubspec.yaml`](../../pubspec.yaml) 的 `version`（name 与/或 build）。
3. 若 **name** 相对上一正式版有变化：更新 [`latest.json`](latest.json)
   - `latest`：与 name 一致（如 `0.2.0`，**不含** `+build`）
   - `notes`：面向用户的更新说明（可空；可写「Beta」）
   - `publishedAt`：发布日（`YYYY-MM-DD`）
   - `channels.*`：有直链则填，否则 `null`（客户端回退 `github`）
   - Android 国内备选：`androidNetdisk`（分享链接）+ `netdiskHint`（提取码等说明，可空）
4. 需要踢掉过旧安装包时，抬高 `minSupported`（低于该版本每次冷启动强提醒，可关但下次仍弹）。仅抬 build、name 不变时一般不用动。
5. 打 GitHub Release（附各平台安装包，如有）；tag 建议与 name 对齐（如 `v0.1.0`）。
   - **Android 文件名规范**（`s1er-<name>+<build>-android-<variant>.apk`）：

     | 文件后缀 | 含义 |
     |:---|:---|
     | `-android-universal.apk` | 合一包（全部 ABI）；应用内更新直链用这个 |
     | `-android-arm64-v8a.apk` | 仅 arm64（多数真机） |
     | `-android-armeabi-v7a.apk` | 仅 32 位 ARM |
     | `-android-x86_64.apk` | 仅 x86_64（模拟器等） |

   - Release 正文由 `release.ps1 create` 自动写入「下哪个包」选型表。
   - **Windows**：`s1er-…-windows-x64.zip`。
6. 将 `pubspec.yaml` + `latest.json` + `whats_new.json` + `CHANGELOG.md` 等改动提交到 `main`（raw URL 指向 main）。

## 半自动分步脚本（推荐）

本机构建与 GitHub 上传拆开，避免长时间干等 CLI 上传（大 APK 在部分网络下极慢；**浏览器拖文件往往更快**）。

```powershell
.\scripts\release.ps1 status          # 当前版本与 dist\ 产物
# ① 先写更新内容：CHANGELOG.md + whats_new.json + latest.json notes
.\scripts\release.ps1 bump-name -BumpName patch   # 或 bump-build
.\scripts\release.ps1 build           # fat + 分架构 APK + Windows zip → dist\（不上传）
.\scripts\release.ps1 create          # 建空 Release + 打开网页
# 在网页上把 dist\ 里的 apk / zip 拖上去
.\scripts\release.ps1 manifest        # 写 latest.json 直链
# ② 提交到 main：pubspec.yaml + latest.json + whats_new.json + CHANGELOG.md
git add pubspec.yaml docs/release/latest.json assets/changelog/whats_new.json CHANGELOG.md
git commit --no-verify -m "chore(release): vX.Y.Z+1"
git push origin main
```

升产品版本（应用内会提示更新）：

```powershell
# ① 先写更新内容：CHANGELOG.md + whats_new.json + latest.json notes
.\scripts\release.ps1 bump-name -BumpName patch   # 或 minor / major
.\scripts\release.ps1 build
.\scripts\release.ps1 create
# 浏览器上传 …
.\scripts\release.ps1 manifest
# ② 提交到 main
git add pubspec.yaml docs/release/latest.json assets/changelog/whats_new.json CHANGELOG.md
git commit --no-verify -m "chore(release): vX.Y.Z+1"
git push origin main
```

可选：`.\scripts\release.ps1 upload` 用 `gh` 传附件（慢）；`-SkipApk` / `-SkipWindows` 只打一端；`-DryRun` 演练。

## 本地覆盖

```bash
flutter run --dart-define=UPDATE_MANIFEST_URL=https://example.com/latest.json
flutter run --dart-define=DISTRIBUTION=play
```

### 清单必须可公开访问

客户端用**未认证** HTTP GET 拉取 `UPDATE_MANIFEST_URL`。若仓库为 **private**，`raw.githubusercontent.com/.../latest.json` 会对公网返回 **404**，启动检查会静默跳过，关于页「检查更新」会提示「更新清单不存在或不可公开访问」。

可选做法：

1. 将仓库设为 public；或
2. 把 `latest.json` 挂到任意公开 HTTPS（Gist / 独立 public 仓库 / CDN），并用 `UPDATE_MANIFEST_URL` 指向它。

### 国内访问与网盘

客户端拉取清单时按序尝试：`UPDATE_MANIFEST_URL`（默认 GitHub raw）→ jsDelivr（`cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json`）。

Android（非 Play）升级 Dialog：

- **立即更新**：应用内下载 `channels.androidApk`（GitHub Releases；国内可能失败）
- **网盘下载**：外链打开 `channels.androidNetdisk`（不解析网盘直链）；`channels.netdiskHint` 展示提取码等说明

填写示例：

```json
"androidNetdisk": "https://pan.quark.cn/s/c05196e3c06a",
"netdiskHint": "夸克网盘（GitHub 下载慢时可走这里）"
```

无网盘时两项可保持 `null`；非法主机不会显示网盘按钮。`release.ps1 manifest` 会保留已有网盘字段，只改版本与 APK/Windows 直链。
