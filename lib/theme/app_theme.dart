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
  static const inputShape = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
}

/// M3 底部固定栏（NavigationBar / PaginationBar）共用表面样式。
///
/// 与内容区的分隔靠 [ColorScheme.surface] vs [ColorScheme.surfaceContainer]
/// 的色阶差实现，不使用 outline 描边（与 M3 NavigationBar 一致）。
abstract class S1BottomBarStyle {
  static const double minTouchTarget = 48;
  static const double barVerticalPadding = 4;

  /// 分页栏内容行高（48dp 触控 + 上下 padding）。
  static const double paginationBarHeight = minTouchTarget + barVerticalPadding * 2;

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
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.secondaryContainer;
        }
        // M3 未选中段透明底；见 AGENTS.md「M3 已知例外」
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.onSecondaryContainer;
        }
        return scheme.onSurfaceVariant;
      }),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(borderRadius: S1Shape.medium),
      ),
    );
  }
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
}

class AppTheme {
  static const Map<String, Color> themeSeeds = {
    'blue': Color(0xFF1A73E8),
    'purple': Color(0xFF6750A4),
    'sage': Color(0xFF386B52),
    'indigo': Color(0xFF435993),
    'orange': Color(0xFFF57C00),
  };



  static ThemeData lightTheme(String themeColorKey) {
    final seedColor = themeSeeds[themeColorKey] ?? themeSeeds['purple']!;
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
    );
  }

  static ThemeData darkTheme(String themeColorKey) {
    final seedColor = themeSeeds[themeColorKey] ?? themeSeeds['purple']!;
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
    );
  }

  static ThemeData fromColorScheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        shape: S1Shape.cardShape,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dialogTheme: const DialogThemeData(shape: S1Shape.dialogShape),
      bottomSheetTheme: const BottomSheetThemeData(shape: S1Shape.bottomSheetShape),
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
          backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: WidgetStatePropertyAll(colorScheme.shadow),
          surfaceTintColor: WidgetStatePropertyAll(colorScheme.surfaceTint),
          shape: const WidgetStatePropertyAll(S1Shape.menuShape),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
        ),
      ),
      menuButtonTheme: const MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(112, 48)),
          maximumSize: WidgetStatePropertyAll(Size(280, double.infinity)),
          padding: WidgetStatePropertyAll(EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0)),
          alignment: AlignmentDirectional.centerStart,
          iconSize: WidgetStatePropertyAll(24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 3,
        shape: S1Shape.menuShape,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: S1Shape.menuShape,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: S1BottomBarStyle.background(colorScheme),
        indicatorColor: colorScheme.secondaryContainer,
        surfaceTintColor: colorScheme.surfaceTint,
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
    );
  }
}
