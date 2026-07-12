import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 's1_menu.dart';

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
    return S1IconMenuAnchor(
      menuChildren: [
        if (onRefresh != null)
          s1MenuItem(
            onPressed: onRefresh,
            icon: Icons.refresh,
            label: '刷新',
          ),
        s1MenuItem(
          onPressed: () => launchUrl(Uri.parse(browserUrl)),
          icon: Icons.open_in_browser,
          label: '通过浏览器打开',
        ),
      ],
    );
  }
}
