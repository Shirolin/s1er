import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/s1_haptics.dart';
import '../utils/post_link_resolver.dart';
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
    this.showOpenLink = false,
  });

  final VoidCallback? onRefresh;
  final String browserUrl;
  final BrowserUrlLauncher launcher;
  final bool showOpenLink;

  Future<void> _copyPageLink(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: browserUrl));
    } catch (_) {
      // Clipboard may not be available in all environments.
    }
    if (!context.mounted) return;
    S1Haptics.light();
    S1SnackBar.show(context, message: '已复制');
  }

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

  Future<void> _openLinkDialog(BuildContext context) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          title: const Text('输入链接'),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '粘贴 S1 帖子或版块链接',
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste),
                tooltip: '粘贴',
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text case final text?) {
                    controller.text = text;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                },
              ),
            ),
            onSubmitted: (value) => _handleLinkSubmit(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  _handleLinkSubmit(dialogContext, controller.text),
              child: const Text('跳转'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    focusNode.dispose();
  }

  void _handleLinkSubmit(BuildContext context, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final result = PostLinkResolver.resolve(trimmed);
    switch (result) {
      case InternalPostLink(:final location):
        _navigateAndPop(context, location);
      case ExternalPostLink():
        S1SnackBar.show(context, message: '仅支持 S1 论坛链接');
      case InvalidPostLink():
        S1SnackBar.show(context, message: '无效链接');
    }
  }

  void _navigateAndPop(BuildContext context, String location) {
    final router = GoRouter.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.pop(context);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.push(location);
      });
    });
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
            _copyPageLink(context);
          },
          icon: Icons.link,
          label: '复制链接',
        ),
        s1MenuItem(
          onPressed: () {
            S1Haptics.selection();
            _openBrowser(context);
          },
          icon: Icons.open_in_browser,
          label: '通过浏览器打开',
        ),
        if (showOpenLink)
          s1MenuItem(
            onPressed: () {
              S1Haptics.selection();
              _openLinkDialog(context);
            },
            icon: Icons.add_link,
            label: '输入链接',
          ),
      ],
    );
  }
}
