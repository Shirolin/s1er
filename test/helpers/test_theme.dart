import 'package:flutter/material.dart';
import 'package:s1_app/theme/app_theme.dart';

/// 测试用 MaterialApp 包裹，使用与生产一致的 [AppTheme]。
Widget wrapWithAppTheme(
  Widget child, {
  String seed = 'purple',
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme(seed),
    home: Scaffold(body: child),
  );
}
