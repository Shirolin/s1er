import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// 系统底栏（Android 导航栏）图标亮度的全局声明。
///
/// 应用自绘底部 chrome 色（`S1BottomBarStyle.background`）后必须显式告知 Android
/// 用深色还是浅色图标，否则传统三键导航下会出现「白底白图标」：
///
/// 1. Flutter 每帧在屏幕**底部中心**取 `AnnotatedRegion<SystemUiOverlayStyle>`
///    的导航栏字段（`RenderView._updateSystemChrome`）；取不到就回退用顶部
///    AppBar 的注解。
/// 2. AppBar 的自动注解**按设计不含**导航栏字段（`_systemOverlayStyleForBrightness`
///    的 backward-compat 注释），于是 `systemNavigationBarIconBrightness == null`。
/// 3. 引擎 `setSystemChromeSystemUIOverlayStyle` 有 `!= null` 守卫，字段为空时
///    从不调用 `setAppearanceLightNavigationBars`，图标亮度退回 Activity 主题默认
///    （`Theme.Light.NoTitleBar` / `Theme.Black.NoTitleBar` 默认均为浅色图标）。
///
/// 必须放在 `MaterialApp.builder` 内 —— 那里位于 `Theme` / `AnimatedTheme` 之内
/// 且铺满全屏，既能读取应用内 [ColorScheme.brightness]（`themeMode` 可被用户强选，
/// Android XML 主题无法跟随），又能保证底部中心命中本注解。AppBar 的注解自带尺寸、
/// 仅覆盖顶部，因此不会被本注解遮蔽，形成官方推荐的「顶部取状态栏、底部取导航栏」模型。
///
/// 底部为深底的沉浸页（`image_viewer_screen`）须自带
/// `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light)` 覆盖本默认。
class S1BottomOverlayStyle extends StatelessWidget {
  const S1BottomOverlayStyle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarIconBrightness: scheme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        // API 35+ 起 setNavigationBarColor 对颜色生效范围受限（引擎仅在
        // SDK_INT < API_35 时调用），导航栏底色一律由自绘色带承担
        // （S1BottomBarStyle.background），故这里不需要颜色。
        systemNavigationBarColor: Colors.transparent,
        // 底色由自绘色带保证对比度，关掉系统 80% 不透明 scrim，避免叠加成更亮的白底。
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}
