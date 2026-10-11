# 应用升级与版本管理

客户端通过 `EnvConfig.updateManifestUrl`（默认 jsDelivr CDN：`cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json`，与本目录 [`latest.json`](latest.json) 同源）拉取版本信息，用于应用内升级提醒。

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

每次对外发布安装包时，**build 必须比上一包大**（受 Android `versionCode` 覆盖安装防降级限制 `INSTALL_FAILED_VERSION_DOWNGRADE`，即使升级产品版本 `name`，`build` 也不可重置为 `+1`，必须全局单调递增）。

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
   - **Android APK 直链**（`release.ps1 manifest` 自动写入；应用内更新按 ABI 选包）：

     | JSON 字段 | 对应产物 | 用途 |
     |:---|:---|:---|
     | `androidArm64V8aApk` | `-android-arm64-v8a.apk` | arm64 真机；**应用内更新优先** |
     | `androidArmeabiV7aApk` | `-android-armeabi-v7a.apk` | 32 位 ARM |
     | `androidX8664Apk` | `-android-x86_64.apk` | 模拟器 / x86_64 设备 |
     | `androidApk` | `-android-universal.apk` | 无法识别 ABI 或分架构字段缺失时的**回退** |

   - Android 国内备选：`androidNetdisk`（分享链接）+ `netdiskHint`（提取码等说明，可空）
   - iOS：`ios`（TestFlight / App Store 链接）；未上架填 `null`，客户端回退 `github` 发布页。**网盘与 Play 链接仅对 Android 展示**，iOS/Web 升级弹窗不会露出安卓包入口
4. 需要踢掉过旧安装包时，抬高 `minSupported`（低于该版本每次冷启动强提醒，可关但下次仍弹）。仅抬 build、name 不变时一般不用动。
5. 打 GitHub Release（附各平台安装包，如有）；tag 建议与 name 对齐（如 `v0.1.0`）。
   - **Android 文件名规范**（`s1er-<name>+<build>-android-<variant>.apk`）：

     | 文件后缀 | 含义 |
     |:---|:---|
     | `-android-universal.apk` | 合一包（全部 ABI，无法识别架构时的回退） |
     | `-android-arm64-v8a.apk` | 仅 arm64（多数真机；应用内更新优先） |
     | `-android-armeabi-v7a.apk` | 仅 32 位 ARM |
     | `-android-x86_64.apk` | 仅 x86_64（模拟器等） |

   `release.ps1 manifest` 会把上述四个 APK 直链写入 `latest.json`（`androidApk` + `androidArm64V8aApk` 等）；客户端按设备 ABI 选包，识别失败时回退 universal。**不要只手改 `latest.json` 而跳过 `manifest`**——旧版脚本曾只写 universal，下次发版会把分架构字段冲掉（v0.3.4 即发生过）。

   - Release 正文由 `release.ps1 create` 自动生成：抽取 `CHANGELOG.md` 本版段作为「更新内容」（`### Added/Changed/Fixed` 转 `**新增/变更/修复**`，其余 `###` 降为 `####`），再接「下哪个包」选型表；CHANGELOG 缺该段或为空时 `create` 直接报错，不再出现只有下载表的正文。
   - **Windows**：`s1er-…-windows-x64.zip`。
6. 将 `pubspec.yaml` + `latest.json` + `whats_new.json` + `CHANGELOG.md` 等改动提交到 `main`，推送后**主动刷新 jsDelivr 缓存**：

   ```powershell
   git push origin main
   Invoke-RestMethod https://purge.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json
   ```

   jsDelivr 对 `@main` 分支内容有 CDN 缓存，**只推送不 purge 时可能仍返回上一版清单**（0.8.0 发版实测如此），应用内更新会滞后数小时；purge 返回 `"status": "finished"` 即各边缘节点已回源新内容。GitHub raw 备用源不受此影响。

## 半自动分步脚本（推荐）

> 脚本统一用 **PowerShell 7（`pwsh`）** 运行（本机已装；勿用 Windows PowerShell 5.1，默认 ANSI 编解码会读坏 `latest.json` 中文、写坏 pubspec 字节）。
> `bump-name` 会递增产品版本并**保留单调递增的 build**（不重置为 `+1`），符合 Android `versionCode` 防降级规则。

本机构建与 GitHub 上传拆开，避免长时间干等 CLI 上传（大 APK 在部分网络下极慢；**浏览器拖文件往往更快**）。

```powershell
pwsh -File .\scripts\release.ps1 status          # 当前版本与 dist\ 产物
# ① 先写更新内容：CHANGELOG.md + whats_new.json + latest.json notes
pwsh -File .\scripts\release.ps1 bump-name -BumpName patch   # 或 bump-build
pwsh -File .\scripts\release.ps1 build           # fat + 分架构 APK + Windows zip → dist\（不上传）
pwsh -File .\scripts\release.ps1 create          # 建空 Release + 打开网页
# 在网页上把 dist\ 里的 apk / zip 拖上去
pwsh -File .\scripts\release.ps1 manifest        # 写 latest.json 直链（含四个 Android APK；缺一会报错）
# ② 提交到 main
git add pubspec.yaml docs/release/latest.json assets/changelog/whats_new.json CHANGELOG.md
git commit --no-verify -m "chore(release): vX.Y.Z+1"
git push origin main
Invoke-RestMethod https://purge.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json   # 刷新 jsDelivr 缓存
```

升产品版本（应用内会提示更新）：

```powershell
# ① 先写更新内容：CHANGELOG.md + whats_new.json + latest.json notes
pwsh -File .\scripts\release.ps1 bump-name -BumpName patch   # 或 minor / major
pwsh -File .\scripts\release.ps1 build
pwsh -File .\scripts\release.ps1 create
# 浏览器上传 …
pwsh -File .\scripts\release.ps1 manifest        # 写 latest.json 直链（含四个 Android APK；缺一会报错）
# ② 提交到 main
git add pubspec.yaml docs/release/latest.json assets/changelog/whats_new.json CHANGELOG.md
git commit --no-verify -m "chore(release): vX.Y.Z+1"
git push origin main
Invoke-RestMethod https://purge.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json   # 刷新 jsDelivr 缓存
```

可选：`pwsh -File .\scripts\release.ps1 upload` 用 `gh` 传附件（慢）；`-SkipApk` / `-SkipWindows` 只打一端；`-DryRun` 演练。

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

客户端拉取清单时**并发竞速**（Fastest-Wins，单源超时 5 秒）：

1. `UPDATE_MANIFEST_URL`（默认 jsDelivr：`cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json`）
2. GitHub raw 备用（`raw.githubusercontent.com/Shirolin/s1er/main/docs/release/latest.json`）

任一源先返回合法 JSON 即采用；备用源超时可能打出 warning 日志，不影响主源已成功时的检查结果。

Android（非 Play）升级 Dialog：

- **立即更新**：应用内按设备 ABI 下载对应 APK（优先 `androidArm64V8aApk` / `androidArmeabiV7aApk` / `androidX8664Apk`；清单缺字段或识别失败时回退 `androidApk` universal）。下载在收到完整 `Content-Length` 后即结束，不等 GitHub CDN 关闭连接（否则会超时失败）。
- **系统下载**（应用内直链失败后的 Android 备选）：交给系统 DownloadManager，完成后调起安装。**不要**用浏览器打开 GitHub `releases/download/*.apk` 直链——手机 Chrome 常会卡在 100% 且不出安装按钮。
- **下载主机白名单**：`UpdateCheckService.allowedDownloadHosts`（Dart）与 `MainActivity.kt` 的 `allowedDownloadHosts` 须保持同步；改任一侧后跑 `update_check_service_test` 并人工核对另一侧。
- **网盘下载**：外链打开 `channels.androidNetdisk`（不解析网盘直链）；`channels.netdiskHint` 展示提取码等说明。国内网络下这是最稳的安装包来源。

`latest.json` 示例（节选）：

```json
"channels": {
  "androidApk": "https://github.com/.../s1er-0.3.5+1-android-universal.apk",
  "androidArm64V8aApk": "https://github.com/.../s1er-0.3.5+1-android-arm64-v8a.apk",
  "androidArmeabiV7aApk": "https://github.com/.../s1er-0.3.5+1-android-armeabi-v7a.apk",
  "androidX8664Apk": "https://github.com/.../s1er-0.3.5+1-android-x86_64.apk",
  "androidNetdisk": "https://pan.quark.cn/s/c05196e3c06a",
  "netdiskHint": "夸克网盘（GitHub 下载慢时可走这里）"
}
```

无网盘时 `androidNetdisk` / `netdiskHint` 可保持 `null`；非法主机不会显示网盘按钮。`release.ps1 manifest` 会保留已有网盘字段，并重写全部 APK 与 Windows 直链。

### Windows 绿色包

产物仍是 `s1er-…-windows-x64.zip`（解压后运行 `s1er.exe`）。客户端在 Windows 上若清单含合法 `channels.windows` `.zip` 直链，升级 Dialog 的主按钮为 **立即更新**：

1. 应用内下载 ZIP（与 Android 相同的「收满即结束」逻辑）
2. 解压到安装目录内的 `.s1er-staging`，确认包内有合法的 `s1er.exe`（PE 头）
3. **逐文件热替换**（不依赖 PowerShell / 外部脚本 / 辅助进程）：把当前工作目录移出安装目录 → 新包每个文件先让位（旧文件改名为 `*.s1erold`）再就位 → 以安装目录为工作目录 detached 拉起新 `s1er.exe` → **等新进程写「已启动」标记**（`main()` 早期写入，见下）后才 `exit(0)`
   - 之所以是「文件级」而非「整目录对换」：Windows 上运行中的 exe / DLL **文件**可以改名（但所在**目录**不能改名，实测 `Access denied`），因此由运行中的旧进程**自己**完成覆盖，无需 PowerShell、无需等它退出、无重启空窗
   - ⚠️ **前提**：该方案假定运行中的 `s1er.exe` 与已加载 DLL（含 `data/icudtl.dat`）可改名。这是 Windows 通用行为，但未在 s1er 自身产物上逐文件验证；若个别文件被占用，本次更新会整体回滚并报错（不会破坏安装目录）
4. 任一步失败（文件被占用、**新版本启动超时/未能运行**）都会**整体回滚**：删掉已就位的新文件与本次新建的空目录、把 `*.s1erold` 改回原名，当前进程继续运行并报错；下次启动 best-effort 清掉残留
5. 更新失败的版本会记入设置（版本 + 原因）；冷启动自动检查对该版本**退避**（不再反复弹），关于页「检查更新」手动仍会展示并带上原因。**下载**失败不记入退避（与应用无关），仅提示
6. 用户数据在 `%APPDATA%`，不在安装目录里，覆盖程序文件不会清登录态

下次点更新时会先清掉上次留下的 `*.s1erold` 与 `.s1er-staging*`。失败时仍可「浏览器打开」ZIP 手动解压覆盖。调试/`build\windows\runner` 开发目录、以及没有写入权限的目录（如 Program Files）会拒绝覆盖。

「已启动」标记经环境变量 `S1ER_STARTED_MARKER` 传给新进程，由 `lib/utils/update_startup_marker.dart` 在 `main()` 首行写入。

### 本地端到端测试覆盖更新（不触碰线上）

要在**不影响线上发布**的前提下点完整「立即更新」流程，用本地逃生阀 + 本地服务器：

```powershell
# ① 构建 profile/debug 包（注入本地清单地址与逃生阀）+ 打包 zip + 拷到普通目录
pwsh -File scripts/test_update_local.ps1 -Mode profile
# ② 起本地升级服务器（提供 latest.json 与 zip）
dart run scripts/serve_update_local.dart --zip dist\local-update-test\s1er-0.9.0-windows-x64.zip --version 0.9.0 --port 8099
# ③ 直接运行安装目录里的 exe（不是 flutter run——debug 包在 build\ 下会被拒）
& dist\local-update-test\install\s1er.exe
```

然后 关于 → 检查更新 → 立即更新，观察是否闪一下即重启到新版。

安全边界：

- 逃生阀 `UPDATE_ALLOW_LOCAL_HOST` **仅 debug/profile 生效**（`kReleaseMode` 为真时恒关闭），且只放行环回主机 `127.0.0.1`/`localhost`/`::1` 的 `http`；release 发布包即使被传入该 define 也不会放行本地主机。
- 主清单指向环回地址时，客户端**不再并发线上备用源**，避免真实网络干扰本地验证。
- 全程只连本机，不请求 GitHub / jsDelivr / 论坛。
