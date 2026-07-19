# 启动器图标（App Icon）

运行时可切换的桌面图标。目录：`lib/config/app_icon_catalog.dart`；生成：`dart run scripts/sync_app_icons.dart`。设置页备注「重启生效」。

## 资源角色（`assets/branding/`）

| 文件 | 用途 |
|---|---|
| `s1er_logo_black.png` / `s1er_logo_white.png` / `s1er_logo_xb2.png` 等 | **成品方图**（底色 + logo 已合成）。设置预览；主题款（如 xb2）兼作 Android/iOS master |
| `s1er_logo_transparent.png` | **仅**黑/白 solid-plate adaptive 的共享透明前景；不是成品预览 |
| `s1er_mark.png` | 应用内品牌标，**不是**启动器图标 |

新增主题图标：放成品方 PNG → 在 `AppIconCatalog.variants` 登记 → 跑 sync → **提交生成的** `android/` / `ios/` 资源。

## Android 两条管线（勿混用）

`AppIconCatalog.adaptiveInsetPercent = 16`（与 stock `ic_launcher` / `flutter_launcher_icons` 一致）。

### A. Solid-plate（黑 / 白）

- **黑**：`reuseExistingAndroid: true`，复用 `@mipmap/ic_launcher`，**禁止** sync 重生成。
- **白**：纯色底板 + 共享 `ic_launcher_foreground`（来自 transparent）+ **前景 16% inset**。

适用：透明 logo + 单色底板。16% 是把 **logo 缩进安全区**，外圈靠底板铺满圆罩。

### B. 成品主题图（`androidMasterAsIcon: true`，如 xb2）

成品图已含复杂底色，贴边紧。正确做法：

1. **前景**：整张 master + **同一套 16% inset**（完整构图留在安全区，避免圆罩「裁多了」）。
2. **背景**：同一张 master **铺满**（0% inset），外圈继续金/粉等底色（避免白圆套方块）。
3. **Legacy mipmap**：仅等比缩放到各密度，作 API &lt; 26 回退。

```xml
<!-- 语义示意；以 sync 产出为准 -->
<adaptive-icon>
  <background android:drawable="@drawable/ic_launcher_*_background"/>
  <foreground>
    <inset android:drawable="@drawable/ic_launcher_*_foreground"
           android:inset="16%" />
  </foreground>
</adaptive-icon>
```

## 禁止（踩过的坑）

| 错误做法 | 结果 |
|---|---|
| 成品图 **只出 mipmap**、不要 adaptive | 现代启动器当 legacy → **白圆套小方块** |
| 成品图 adaptive **0% inset、仅 background** | 圆罩吃掉贴边内容 → **像放大裁多了** |
| 成品图再套 16% + **纯白/单色底板** | 安全区对了，但外圈变成色块 → **圆里套小方块** |
| 对成品图再跑「transparent + 16%」或二次 inset/crop | 构图被二次缩小 |
| 把 `s1er_logo_transparent` 当主题预览 / 当 xb2 master | 资源角色错乱 |

**结论**：黑白那套 **16% 一直是对的**；成品主题图也要 **16% 前景**，但背景必须是 **同图 full-bleed**，不是删 adaptive，也不是 0% 单层。

## 其它平台

- **iOS**：alternate icons（`AppIcon-<id>@2x/3x`）；系统确认弹窗；设置文案另有提示。
- **Windows**：仅默认黑底 exe/任务栏图标，`dart run scripts/gen_windows_icon.dart`；无运行时切换。
- **Web / 桌面其它**：无启动器切换；设置项仅 Android / iOS 显示。

## 相关文件

- Catalog：`lib/config/app_icon_catalog.dart`
- Sync：`scripts/sync_app_icons.dart`
- UI：`lib/widgets/settings/app_icon_picker.dart`
- Native：`MainActivity.kt` / `AppDelegate.swift` + activity-alias / `CFBundleAlternateIcons`
- 备份字段：`app_icon`（见 `docs/backup-format-v1.md`）
