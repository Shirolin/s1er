import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 系统底栏（传统三键导航 / 手势条）占位色带。
///
/// 与 [PaginationBar]、[NavigationBar] 共用 [S1BottomBarStyle] 表面色，
/// 避免无底部 chrome 时内容区下方露出窗口黑边，并让 FAB 落在系统栏之上。
class S1SystemBottomInset extends StatelessWidget {
  const S1SystemBottomInset({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (bottom <= 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: S1BottomBarStyle.background(scheme),
      child: SizedBox(width: double.infinity, height: bottom),
    );
  }
}
