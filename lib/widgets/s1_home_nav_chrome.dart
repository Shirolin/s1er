import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 首页底部 [NavigationBar] 外壳：延伸 chrome 色并避让系统导航栏。
class S1HomeNavChrome extends StatelessWidget {
  const S1HomeNavChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: S1BottomBarStyle.background(Theme.of(context).colorScheme),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: child,
      ),
    );
  }
}
