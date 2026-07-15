import 'package:flutter/material.dart';

/// M3 Shape tokens — 统一圆角半径
abstract class S1Shape {
  static const extraSmall = BorderRadius.all(Radius.circular(4));
  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(12));
  static const large = BorderRadius.all(Radius.circular(16));
  static const extraLarge = BorderRadius.all(Radius.circular(28));

  /// 全圆角（胶囊 / pill），用于标签、徽标等 M3 "full" 形状。
  static const full = BorderRadius.all(Radius.circular(999));

  static const cardShape = RoundedRectangleBorder(borderRadius: medium);
  static const dialogShape = RoundedRectangleBorder(borderRadius: extraLarge);
  static const bottomSheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );
  static const chipShape = RoundedRectangleBorder(borderRadius: small);
  static const menuShape = RoundedRectangleBorder(borderRadius: small);
  static const inputShape =
      OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
}

/// M3 底部固定栏（NavigationBar / PaginationBar）共用表面样式。
///
/// 与内容区的分隔靠 [ColorScheme.surface] vs [ColorScheme.surfaceContainer]
/// 的色阶差实现，不使用 outline 描边（与 M3 NavigationBar 一致）。
abstract class S1BottomBarStyle {
  static const double minTouchTarget = 48;
  static const double barVerticalPadding = 4;

  /// 分页栏内容行高（48dp 触控 + 上下 padding）。
  static const double paginationBarHeight =
      minTouchTarget + barVerticalPadding * 2;

  static Color background(ColorScheme scheme) => scheme.surfaceContainer;

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

  /// 代码块默认字号（bodySmall 档）。
  static const int defaultCodeSize = 12;

  static const double defaultBodyLineHeight = 1.6;

  static double bodySize(TextTheme textTheme) =>
      textTheme.bodyMedium?.fontSize ?? defaultBodySize.toDouble();

  static double codeSize(TextTheme textTheme) =>
      textTheme.bodySmall?.fontSize ?? defaultCodeSize.toDouble();

  static double bodyLineHeight(TextTheme textTheme) =>
      textTheme.bodyMedium?.height ?? defaultBodyLineHeight;
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
  static const defaultThemeColorKey = 'purple';

  static const Map<String, Color> themeSeeds = {
    'blue': Color(0xFF1A73E8),
    'purple': Color(0xFF6750A4),
    'sage': Color(0xFF386B52),
    'indigo': Color(0xFF435993),
    'orange': Color(0xFFF57C00),
  };

  static String normalizeThemeColorKey(String? key) =>
      themeSeeds.containsKey(key) ? key! : defaultThemeColorKey;

  static ThemeData lightTheme(String themeColorKey) {
    final seedColor = themeSeeds[normalizeThemeColorKey(themeColorKey)]!;
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
    );
  }

  static ThemeData darkTheme(String themeColorKey) {
    final seedColor = themeSeeds[normalizeThemeColorKey(themeColorKey)]!;
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
    );
  }

  static ThemeData fromColorScheme(ColorScheme colorScheme) {
    final textTheme =
        ThemeData(useMaterial3: true, colorScheme: colorScheme).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: S1Shape.cardShape,
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dialogTheme: const DialogThemeData(shape: S1Shape.dialogShape),
      bottomSheetTheme:
          const BottomSheetThemeData(shape: S1Shape.bottomSheetShape),
      chipTheme: const ChipThemeData(shape: S1Shape.chipShape),
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
        backgroundColor: colorScheme.surface,
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
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        highlightElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(elevation: 0),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(elevation: 0),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: S1Shape.small),
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(visualDensity: VisualDensity.standard),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        textColor: colorScheme.onSecondaryContainer,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
      ),
      switchTheme: SwitchThemeData(
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
    );
  }
}
