# 0011. 字体策略：桌面钉系统族、等宽独立成族、阅读排版与 UI 排版分离

- 状态：已接受
- 日期：2026-11-12
- 相关：`lib/theme/app_theme.dart`（`S1Fonts` / `S1Typography`）、`lib/theme/s1_text_scaler.dart`、`lib/services/font_import_service.dart`、`lib/widgets/bbcode_renderer.dart`、`lib/main.dart`

## 背景

项目不打包任何字体（`pubspec.yaml` 无 `fonts:` 段），全部依赖平台字体 + 引擎自带图标字体。这个前提下有三件事代码本身推不出来：

1. **Windows 的拉丁观感差，且无法靠渲染层解决。** 实测 Flutter 3.47 在 Windows 上默认走 Impeller 的 SDF 文字（`--no-enable-impeller` 不生效，截图逐像素相同），全平台灰度抗锯齿、无 ClearType。能调的只有字形、字重、字号、行距。
2. **桌面引擎按已安装字体名精确查找**，不认 CSS 泛型 `monospace`；把主题族直接当等宽族用，代码块会渲染成无衬线。
3. **`flutter_html` 的根节点不参与 `style` map 的标签匹配**（`'body'` / `'html'` / `'*'` 实测都改不动根样式），根样式恒取自 `Theme.of(context).textTheme.bodyMedium`。

## 决策

1. **桌面钉系统 UI 族，移动与 Web 保持框架默认（`null`）。** 拉丁优先取平台的现代 UI 字体（可变字体的 Text 光学尺寸用于正文、Display 用于 22px 以上的标题档），CJK 交给回退链落到系统中文族。族名映射见 `S1Fonts`，不在文档里重复。
2. **等宽是独立语义族**，按平台给真实字体名，并显式带一条包含正文字族的回退链（代码块里的中文注释不能出豆腐）。禁止从 `textTheme` 派生等宽族。
3. **应用内字号档位叠在平台无障碍缩放之上**，而不是替换（`MediaQuery.copyWith(textScaler:)` 会丢弃系统字号）；总比例做上下限夹取，防止叠乘撑破布局；持久化的旧档位值在恢复设置时夹到最近档。复合顺序是**先档位、再平台曲线**（`platform.scale(size * factor)`），两者不可交换：把平台曲线放在最外层，才能保证大档位不会突破系统设定的可访问性上限。除 [TextScaler.scale] 外还需实现抽象成员 `textScaleFactor`（仅向后兼容）与 `==`/`hashCode`（避免 `MediaQuery` 每帧不等、排版缓存失效）。
4. **阅读排版与 UI 排版分离。** 正文的字号取 `S1Typography.defaultBodySize`、行高取 `readingLineHeight`，不取 `bodyMedium`——M3 的 `bodyMedium.height`（1.43）是给 UI 标签的，长文阅读偏紧；分享卡与阅读页共用同一行高 token，避免导出图比阅读页更疏。
5. **正文样式挂在显式容器类上**（`<div class="s1-body">`），因为 `flutter_html` 的根节点不吃 `'body'` 选择器（见背景 3）。
6. **自定义字体仅 Native**，且遵守四条：导入前校验 sfnt 容器头与体积上限；族名由**全文件内容**哈希派生（同名族重复注册多个 typeface 时引擎匹配顺序不可控，会出现"换了字体却不生效"）；导入先写临时文件、引擎激活成功后再改名落盘，避免坏字体留在盘上；冷启动在首帧构建主题**之前** await 注册（`FontLoader.load()` 不触发重建），恢复失败分两类处理——内容无效则删文件并清设置，读取失败（IO）保留文件与设置、下次启动重试。

## 结果

- Windows 的拉丁字母与数字明显清爽，中文一个字形都没变，安装包体积零增长；Android / iOS / Web 的 UI 族不变，代码块等宽族按决策 2 改为平台真实族名（Android 仍落 `monospace` 别名）。
- 系统字号的用户设置不再被应用忽略（Android 生效；iOS 与桌面引擎目前恒报 1.0）。
- 代价：桌面观感依赖系统已安装字体（Linux 无 CJK 字体时只能回退到引擎默认）；拉丁与中文混排时拉丁略细，没有 per-glyph 字重可调。

## 备选方案

- **打包 CJK 字体或子集**：安装包 +5～15 MB，且需处理字体许可证；与"零体积"取向冲突。否决。
- **`google_fonts`**：运行期网络依赖，桌面离线不可靠。否决。
- **改 `textTheme.bodyMedium.height` 来调正文行高**：会连带所有 UI 文本的间距。否决（见决策 4）。
- **引入 `flutter_localizations` 只为拿到 `scriptCategory = dense`**：实测 `dense` 与 `englishLike` 只差 `textBaseline`，字号行高相同，收益不足以抵消依赖成本。否决。
- **用 CSS 泛型 `monospace` 做等宽**：桌面引擎不认。否决（见背景 2）。

## 未决定 / 已知缺陷

- **作者 `font-size` 是否默认剥离**：目前仅在"剥离特殊样式"开关下剥，默认保留，作者可用绝对字号压过用户的字号档位。属产品行为变更，未定。
- **`<ul><li>` 的多个列表项会被拼成一行**：`li` 没有设 `display: listItem` 所致，与本 ADR 的改动无关（A/B 已验证），独立修复。
- **打包 Latin-only 字体**（Inter / Source Sans 3 子集，约 200–400 KB）作为"彻底掌控观感"的下一步选项，尚未采用。
