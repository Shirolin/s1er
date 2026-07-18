import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/s1_haptics.dart';
import '../utils/s1_snack_bar.dart';
import 's1_menu.dart';

typedef BrowserUrlLauncher = Future<bool> Function(
  Uri url, {
  LaunchMode mode,
});

class AppBarMoreMenu extends StatelessWidget {
  const AppBarMoreMenu({
    super.key,
    this.onRefresh,
    required this.browserUrl,
    this.launcher = launchUrl,
  });

  final VoidCallback? onRefresh;
  final String browserUrl;
  final BrowserUrlLauncher launcher;

  Future<void> _openBrowser(BuildContext context) async {
    try {
      final launched = await launcher(
        Uri.parse(browserUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        S1SnackBar.show(context, message: '无法打开浏览器');
      }
    } on Object {
      if (context.mounted) {
        S1SnackBar.show(context, message: '无法打开浏览器');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return S1IconMenuAnchor(
      menuChildren: [
        if (onRefresh != null)
          s1MenuItem(
            onPressed: () {
              S1Haptics.light();
              onRefresh!();
            },
            icon: Icons.refresh,
            label: '刷新',
          ),
        s1MenuItem(
          onPressed: () {
            S1Haptics.selection();
            _openBrowser(context);
          },
          icon: Icons.open_in_browser,
          label: '通过浏览器打开',
        ),
      ],
    );
  }
}
