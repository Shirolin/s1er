import 'package:flutter/material.dart';
import 'package:s1er/theme/app_theme.dart';

/// 测试用 MaterialApp 包裹，使用与生产一致的 [AppTheme]。
///
/// [dark] 为 true 时使用 [AppTheme.darkTheme]，用于验证跟随应用内主题的
/// 系统底栏图标亮度等明暗分支。
Widget wrapWithAppTheme(
  Widget child, {
  String seed = 'sand',
  bool dark = false,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme(seed),
    darkTheme: AppTheme.darkTheme(seed),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(body: child),
  );
}
