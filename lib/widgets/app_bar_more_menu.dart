import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return PopupMenuButton<String>(
      tooltip: '更多操作',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'refresh':
            onRefresh?.call();
          case 'open_browser':
            launchUrl(Uri.parse(browserUrl));
        }
      },
      itemBuilder: (context) => [
        if (onRefresh != null)
          const PopupMenuItem(
            value: 'refresh',
            child: ListTile(
              leading: Icon(Icons.refresh),
              title: Text('刷新'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'open_browser',
          child: ListTile(
            leading: Icon(Icons.open_in_browser),
            title: Text('通过浏览器打开'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
