import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 's1_popup_menu.dart';

enum _AppBarAction { refresh, openBrowser }

class AppBarMoreMenu extends StatelessWidget {
  const AppBarMoreMenu({
    super.key,
    this.onRefresh,
    required this.browserUrl,
  });

  final VoidCallback? onRefresh;
  final String browserUrl;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AppBarAction>(
      tooltip: '更多操作',
      icon: const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AppBarAction.refresh:
            onRefresh?.call();
          case _AppBarAction.openBrowser:
            launchUrl(Uri.parse(browserUrl));
        }
      },
      itemBuilder: (context) => [
        if (onRefresh != null)
          s1PopupMenuItem(
            value: _AppBarAction.refresh,
            icon: Icons.refresh,
            label: '刷新',
          ),
        s1PopupMenuItem(
          value: _AppBarAction.openBrowser,
          icon: Icons.open_in_browser,
          label: '通过浏览器打开',
        ),
      ],
    );
  }
}
