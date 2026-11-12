import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 's1_mouse_cursors.dart';

/// M3 Shape tokens — 统一圆角半径
abstract class S1Shape {
  static const extraSmall = BorderRadius.all(Radius.circular(4));
  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(12));
  static const large = BorderRadius.all(Radius.circular(16));
  static const extraLarge = BorderRadius.all(Radius.circular(28));

  /// 全圆角（胶囊 / pill），用于标签、徽标等 M3 "full" 形状。
  static const full = BorderRadius.all(Radius.circular(999));

  /// 卡片 / Chip：无描边（M3 靠色阶分层，不用 outline）。
  static const cardShape = RoundedRectangleBorder(
    borderRadius: medium,
    side: BorderSide.none,
  );
  static const dialogShape = RoundedRectangleBorder(borderRadius: extraLarge);
  static const bottomSheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );
  static const chipShape = RoundedRectangleBorder(
    borderRadius: small,
    side: BorderSide.none,
  );
  static const menuShape = RoundedRectangleBorder(borderRadius: small);
  static const inputShape =
      OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
}

/// M3 表面色阶（对齐官方 Reply + 暖沙种子 `#825500`）。
///
/// 浅色（与 Reply `Color.kt` / 列表卡用法一致的可映射关系）：
/// 1. **画布** [page] = [ColorScheme.surfaceContainerHighest]（`#EDE0D4`）
/// 2. **内容卡 / 阅读面** [card] / [reading] = [ColorScheme.surfaceContainerLow]
///    （`#FFF1E5` 奶油沙；Reply 未选中列表卡用 `surfaceVariant`≈此档）
/// 3. **卡内嵌套** [nestedPanel] / [nestedPanelItem] = High / Highest（评分区等）
/// 4. **强调** = `primaryContainer`（选中）/ `secondaryContainer`（打开）等
///
/// 深色：page=Lowest，card=reading=Container（分组卡与阅读面同一档），
/// nestedPanel=High，nestedPanelItem=Highest。
/// 弱浮层 [floatingControl]：浅色 High（对 Low 卡 / Highest 画布），
/// 深色 Highest（对 Container 卡 / Lowest 画布）。
/// FAB 用 `tertiaryContainer`（Reply 薄荷绿）。导航铬件与画布同色。
abstract class S1Surface {
  static Color page(ColorScheme scheme) => scheme.brightness == Brightness.light
      ? scheme.surfaceContainerHighest
      : scheme.surfaceContainerLowest;

  static Color card(ColorScheme scheme) => scheme.brightness == Brightness.light
      ? scheme.surfaceContainerLow
      : scheme.surfaceContainer;

  /// 主题列表 / 帖内楼层等大面积阅读底：与 [card] 同档。
  static Color reading(ColorScheme scheme) => card(scheme);

  /// 贴在 [reading] 内的嵌套面板（评分区等）：浅色更深、深色略亮，与阅读面错开。
  static Color nestedPanel(ColorScheme scheme) => scheme.surfaceContainerHigh;

  /// 嵌套面板内的条目条：再偏一档，避免与面板糊成一片。
  static Color nestedPanelItem(ColorScheme scheme) =>
      scheme.brightness == Brightness.light
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerHighest;

  /// 叠在内容上的弱浮层（滚动导航组等）：与 [card] / [page] 均错开一档。
  static Color floatingControl(ColorScheme scheme) =>
      scheme.brightness == Brightness.light
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerHighest;

  /// NavigationRail / NavigationBar / PaginationBar — 与画布齐平。
  static Color chrome(ColorScheme scheme) => page(scheme);
}

/// M3 底部固定栏（NavigationBar / PaginationBar）共用表面样式。
///
/// 与画布同色、无 outline（对齐官方 Navigation 与内容区的色阶关系）。
abstract class S1BottomBarStyle {
  static const double minTouchTarget = 48;
  static const double barVerticalPadding = 4;

  /// 分页栏内容行高（48dp 触控 + 上下 padding）。
  static const double paginationBarHeight =
      minTouchTarget + barVerticalPadding * 2;

  static Color background(ColorScheme scheme) => S1Surface.chrome(scheme);

  static BoxDecoration decoration(ColorScheme scheme) => BoxDecoration(
        color: background(scheme),
      );
}

/// 根据背景亮度选择 [ColorScheme] 语义对比色（用于色块上的前景元素）。
abstract class S1Contrast {
  static Color on(Color background, ColorScheme scheme) {
    return background.computeLuminance() > 0.5
        ? scheme.onSurface
        : scheme.surface;
  }
}

/// M3 SegmentedButton 共用样式（设置页主题模式 / 字号选择）。
abstract class S1SegmentedButtonStyle {
  static ButtonStyle forScheme(ColorScheme scheme) {
    return ButtonStyle(
      visualDensity: VisualDensity.standard,
      // 保留 M3 视觉高度之外的 48dp 触控目标，避免紧凑布局牺牲可访问性。
      tapTargetSize: MaterialTapTargetSize.padded,
      // 覆盖 adaptiveClickable（桌面默认箭头）；方案：跟网页习惯用手型。
      mouseCursor: S1MouseCursors.clickable,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.secondaryContainer;
        }
        // M3 未选中段透明底；见 AGENTS.md「M3 允许模式」
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.onSecondaryContainer;
        }
        return scheme.onSurfaceVariant;
      }),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(borderRadius: S1Shape.full),
      ),
    );
  }
}

/// M3 排版常量与桥接（HTML 渲染、设置默认值共用）。
abstract class S1Typography {
  /// 默认正文字号，与字号设置「标准」档一致。
  static const int defaultBodySize = 14;

  /// 设置页的字号档位（升序）。存储值可能来自旧版本或手改，恢复时用
  /// [normalizeBodySize] 夹到最近档。
  static const List<int> bodySizes = [12, 14, 16, 18, 20];

  /// 把任意值夹到最近的字号档位。
  static int normalizeBodySize(int value) => bodySizes.reduce(
        (a, b) => (a - value).abs() <= (b - value).abs() ? a : b,
      );

  /// 代码块默认字号（bodySmall 档）。
  static const int defaultCodeSize = 12;

  /// 阅读排版的行高（正文、长文、分享卡共用）。
  ///
  /// 不取 `bodyMedium.height`：那是 M3 给 UI 标签的 1.43，长文阅读偏紧。
  static const double readingLineHeight = 1.6;

  /// 代码块字号桥接（bodySmall 档）。
  static double codeSize(TextTheme textTheme) =>
      textTheme.bodySmall?.fontSize ?? defaultCodeSize.toDouble();
}

/// 桌面端系统字体（零体积）：避免 Material 默认 Roboto 缺失后按码点乱回退，
/// 导致同句「有的字粗、有的字细」或图标私用区被错误字体画出乱符。
///
/// 不打包 TTF；依赖本机已装字体。拉丁优先系统 UI 字体，中文由回退链兜住
/// （中文 Windows 上即微软雅黑）。
/// 单平台的字体配置。新增平台只需在这里加一项，四个 getter 自动跟随。
typedef _FontProfile = ({
  String? family,
  List<String> fallback,
  String? display,
  String mono,
});

abstract final class S1Fonts {
  static const _webProfile = (
    family: null,
    fallback: <String>[],
    display: null,
    mono: 'monospace',
  );

  static const _windowsProfile = (
    family: 'Segoe UI Variable Text',
    // Win11 自带 Variable Text 光学尺寸；Win10 无此族，降到 Segoe UI。
    fallback: <String>[
      'Segoe UI',
      'Microsoft YaHei UI',
      'Microsoft YaHei',
      'SimHei',
    ],
    display: 'Segoe UI Variable Display',
    mono: 'Consolas',
  );

  static const _macProfile = (
    family: 'PingFang SC',
    fallback: <String>['Hiragino Sans GB', 'Heiti SC'],
    display: null,
    mono: 'Menlo',
  );

  static const _linuxProfile = (
    family: 'Noto Sans CJK SC',
    fallback: <String>[
      'Noto Sans CJK JP',
      'WenQuanYi Micro Hei',
      'Droid Sans Fallback',
    ],
    display: null,
    mono: 'DejaVu Sans Mono',
  );

  /// 移动端保持框架默认族（null）；Android 走 fonts.xml 的 monospace 别名。
  static const _mobileProfile = (
    family: null,
    fallback: <String>[],
    display: null,
    mono: 'monospace',
  );

  static const _iosProfile = (
    family: null,
    fallback: <String>[],
    display: null,
    mono: 'Menlo',
  );

  static _FontProfile get _profile {
    if (kIsWeb) return _webProfile;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => _windowsProfile,
      TargetPlatform.macOS => _macProfile,
      TargetPlatform.linux => _linuxProfile,
      TargetPlatform.iOS => _iosProfile,
      _ => _mobileProfile,
    };
  }

  /// 主族；移动端 / Web 保持框架默认（null）。
  ///
  /// Windows 用 Segoe UI Variable：引擎按字形逐级回退，拉丁 / 数字取 Segoe，
  /// CJK 落到回退链里的雅黑。
  static String? get fontFamily => _profile.family;

  static List<String> get fontFamilyFallback => _profile.fallback;

  /// 大字号档（headline / title）的族：可变字体的 Display 光学尺寸。
  /// 雅黑的拉丁在 22px 上偏宽偏钝，换光学尺寸收益最明显。
  static String? get displayFamily => _profile.display;

  /// 等宽族：桌面引擎按已安装字体名精确查找，不认 CSS 泛型 'monospace'。
  static String get monoFamily => _profile.mono;

  /// 等宽回退链：代码块里的中文注释靠正文字族兜住。
  static List<String> monoFallback(String? bodyFamily) {
    final profile = _profile;
    return <String>[
      if (bodyFamily != null &&
          bodyFamily.isNotEmpty &&
          bodyFamily != profile.mono)
        bodyFamily,
      ...profile.fallback.where((family) => family != profile.mono),
    ];
  }

  /// 把主族 / 回退链写进 [TextTheme]（[Icon] 仍走 MaterialIcons，不受影响）。
  static TextTheme applyTo(TextTheme base) {
    final family = fontFamily;
    final fallback = fontFamilyFallback;
    if (family == null && fallback.isEmpty) return base;
    return base.apply(
      fontFamily: family,
      fontFamilyFallback: fallback,
    );
  }

  /// 把大字号档（22px 以上）切到 [displayFamily]；族不可用时原样返回。
  ///
  /// 只动 headline 与 titleLarge：Display 光学尺寸是为大字号设计的，
  /// 16px 的 titleMedium 仍属 Text 区间，换过去反而偏细。
  static TextTheme applyDisplayFamily(TextTheme base) {
    final family = displayFamily;
    if (family == null) return base;
    final fallback = fontFamilyFallback;
    TextStyle? display(TextStyle? style) =>
        style?.copyWith(fontFamily: family, fontFamilyFallback: fallback);
    return base.copyWith(
      headlineLarge: display(base.headlineLarge),
      headlineMedium: display(base.headlineMedium),
      headlineSmall: display(base.headlineSmall),
      titleLarge: display(base.titleLarge),
    );
  }

  /// 包含运行时自定义字体族时的 TextTheme 应用逻辑。
  static TextTheme applyCustomOrDefault(TextTheme base, String? customFamily) {
    if (customFamily != null && customFamily.isNotEmpty) {
      final family = fontFamily;
      final fallback = fontFamilyFallback;
      return base.apply(
        fontFamily: customFamily,
        fontFamilyFallback: [
          if (family != null) family,
          ...fallback,
        ],
      );
    }
    return applyTo(base);
  }
}

/// M3 动效时长 / 曲线（短过渡与面板进出共用）。
abstract class S1Motion {
  static const Duration rapid = Duration(milliseconds: 100);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 250);
  static const Curve standard = Curves.easeOutCubic;
}

/// M3 Alpha tokens — 统一透明度
abstract class S1Alpha {
  static const subtle = 0.08;
  static const light = 0.1;
  static const medium = 0.3;
  static const cardOverlay = 0.4;
  static const half = 0.5;
  static const strong = 0.7;
  static const prominent = 0.9;

  /// 禁用图标前景（分页栏、IconButton disabled）。
  static const disabledIcon = 0.38;

  /// 图片查看器遮罩文案。
  static const viewerScrim = 0.54;

  /// 图片查看器底部控制栏背景。
  static const controlBar = 0.92;
}

class AppTheme {
  static const defaultThemeColorKey = 'sand';

  /// 预设种子色；经 [ColorScheme.fromSeed] 展开（非手写完整 ColorScheme）。
  ///
  /// - [blue] / [sand]：对齐 Material 文档 Reply 示意（左冷蓝观感 / 右官方默认）
  /// - [purple]：M3 baseline
  /// - 其余：产品自选补充色相
  ///
  /// 历史 key：`indigo` → `rose`，`orange` → `sand`。
  static const Map<String, Color> themeSeeds = {
    // 文档左图「动态主题」冷蓝观感的静态近似（动态取色本身无固定种子）。
    'blue': Color(0xFF00639B),
    // Reply 官方默认 Primary / Theme Builder 种子（文档右图暖沙）。
    'sand': Color(0xFF825500),
    'purple': Color(0xFF6750A4),
    'sage': Color(0xFF4A6741),
    'rose': Color(0xFF8C4A60),
  };

  static String normalizeThemeColorKey(String? key) {
    if (key == 'indigo') return 'rose';
    if (key == 'orange') return 'sand';
    return themeSeeds.containsKey(key) ? key! : defaultThemeColorKey;
  }

  static ThemeData lightTheme(
    String themeColorKey, {
    String? customFontFamily,
  }) {
    final seedColor = themeSeeds[normalizeThemeColorKey(themeColorKey)]!;
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
      customFontFamily: customFontFamily,
    );
  }

  static ThemeData darkTheme(
    String themeColorKey, {
    String? customFontFamily,
  }) {
    final seedColor = themeSeeds[normalizeThemeColorKey(themeColorKey)]!;
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
      customFontFamily: customFontFamily,
    );
  }

  static ThemeData fromColorScheme(
    ColorScheme colorScheme, {
    String? customFontFamily,
  }) {
    final themed = S1Fonts.applyCustomOrDefault(
      ThemeData(useMaterial3: true, colorScheme: colorScheme).textTheme,
      customFontFamily,
    );
    // 大字号档换 Display 光学尺寸；用户导入自定义字体时保持其选择。
    final textTheme =
        customFontFamily == null ? S1Fonts.applyDisplayFamily(themed) : themed;

    final effectiveFontFamily = customFontFamily ?? S1Fonts.fontFamily;
    final effectiveFallback = customFontFamily != null
        ? [
            if (S1Fonts.fontFamily != null) S1Fonts.fontFamily!,
            ...S1Fonts.fontFamilyFallback,
          ]
        : (S1Fonts.fontFamilyFallback.isEmpty
            ? null
            : S1Fonts.fontFamilyFallback);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: effectiveFontFamily,
      fontFamilyFallback: effectiveFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: S1Surface.page(colorScheme),
      // 默认 Material / 路由空隙走画布，避免浅色 `scheme.surface` 近白闪一下。
      canvasColor: S1Surface.page(colorScheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: S1Surface.page(colorScheme),
        // 避免末尾 ⋮ / 菜单锚点贴齐窗口右缘，连带弹出菜单贴边。
        actionsPadding: const EdgeInsetsDirectional.only(end: 8),
      ),
      cardTheme: CardThemeData(
        shape: S1Shape.cardShape,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: S1Surface.card(colorScheme),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dialogTheme: const DialogThemeData(shape: S1Shape.dialogShape),
      bottomSheetTheme:
          const BottomSheetThemeData(shape: S1Shape.bottomSheetShape),
      // 未选中 Chip 用色阶填充，不用描边（对齐 M3 tonal，非 Outlined）。
      chipTheme: ChipThemeData(
        shape: S1Shape.chipShape,
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.surfaceContainerHigh,
        checkmarkColor: colorScheme.onSecondaryContainer,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(colorScheme.outlineVariant),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: S1Shape.inputShape,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainer),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: WidgetStatePropertyAll(colorScheme.shadow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: S1Shape.small,
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
        ),
      ),
      menuButtonTheme: const MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(168, 48)),
          maximumSize: WidgetStatePropertyAll(Size(280, double.infinity)),
          padding: WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
          ),
          alignment: AlignmentDirectional.centerStart,
          iconSize: WidgetStatePropertyAll(24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          mouseCursor: S1MouseCursors.clickable,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: S1Shape.menuShape,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: S1BottomBarStyle.background(colorScheme),
        indicatorColor: colorScheme.secondaryContainer,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: S1BottomBarStyle.background(colorScheme),
        indicatorColor: colorScheme.secondaryContainer,
        selectedIconTheme:
            IconThemeData(color: colorScheme.onSecondaryContainer),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(height: 1.2),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.2,
        ),
        labelType: NavigationRailLabelType.all,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: S1Surface.page(colorScheme),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        dividerColor: colorScheme.outlineVariant,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: S1SegmentedButtonStyle.forScheme(colorScheme),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // Reply：compose FAB = tertiaryContainer（暖沙下为薄荷绿）。
        // elevation 不覆写，沿用 Flutter M3 浮层默认阴影。
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        mouseCursor: S1MouseCursors.clickable,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(elevation: 0).copyWith(
          mouseCursor: S1MouseCursors.clickable,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(elevation: 0).copyWith(
          mouseCursor: S1MouseCursors.clickable,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(elevation: 0).copyWith(
          mouseCursor: S1MouseCursors.clickable,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: S1Shape.small),
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
        mouseCursor: S1MouseCursors.clickable,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(visualDensity: VisualDensity.standard)
            .copyWith(mouseCursor: S1MouseCursors.clickable),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        textColor: colorScheme.onSecondaryContainer,
      ),
      checkboxTheme: CheckboxThemeData(
        mouseCursor: S1MouseCursors.clickable,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
      ),
      switchTheme: SwitchThemeData(
        mouseCursor: S1MouseCursors.clickable,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        // 与内容卡同档，在 tint 页面底上形成同一「浮层」。
        backgroundColor: WidgetStatePropertyAll(S1Surface.card(colorScheme)),
      ),
    );
  }
}
