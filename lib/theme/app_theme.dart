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
  static const inputShape = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
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

  static const _fontFamily = 'NotoSansSC';
  static const _fontFamilyFallback = [
    'PingFang SC',
    'Heiti SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

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
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      appBarTheme: const AppBarTheme(centerTitle: true),
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
    );
  }
}
