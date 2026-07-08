import 'package:flutter/material.dart';

/// M3 Shape tokens — 统一圆角半径
abstract class S1Shape {
  static const extraSmall = BorderRadius.all(Radius.circular(4));
  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(12));
  static const large = BorderRadius.all(Radius.circular(16));
  static const extraLarge = BorderRadius.all(Radius.circular(28));

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
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'NotoSansSC',
      fontFamilyFallback: const [
        'PingFang SC',
        'Heiti SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
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

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'NotoSansSC',
      fontFamilyFallback: const [
        'PingFang SC',
        'Heiti SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
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
