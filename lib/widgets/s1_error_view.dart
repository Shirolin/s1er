import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/app_exceptions.dart';
import '../utils/error_handler.dart';
import '../utils/post_link_resolver.dart';
import '../utils/s1_snack_bar.dart';

typedef ForumWebLauncher = Future<bool> Function(
  Uri uri, {
  LaunchMode mode,
});

class S1ErrorView extends StatelessWidget {
  const S1ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.onLogin,
    this.forumWebUrl = ApiConfig.baseUrl,
    this.forumWebLauncher = launchUrl,
  });
  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onLogin;
  final String forumWebUrl;
  final ForumWebLauncher forumWebLauncher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isLogin = error is LoginRequiredException;
    final isMaintenance = error is ServerMaintenanceException;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLogin
                  ? Icons.lock_outline
                  : isMaintenance
                      ? Icons.build_circle_outlined
                      : Icons.error_outline,
              size: 64,
              color: isLogin
                  ? scheme.onSurfaceVariant
                  : isMaintenance
                      ? scheme.tertiary
                      : scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isLogin
                  ? '请先登录'
                  : isMaintenance
                      ? '论坛维护中'
                      : '加载失败',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isLogin ? '当前 Stage1st 需要登录后查看论坛内容' : _message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (isMaintenance) ...[
              const SizedBox(height: 8),
              Text(
                '请稍后再试',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (isLogin)
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login),
                label: const Text('去登录'),
              )
            else ...[
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              if (isMaintenance) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openForumWeb(context),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('打开网页版论坛'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openForumWeb(BuildContext context) async {
    final uri = Uri.tryParse(forumWebUrl);
    if (uri == null || !PostLinkResolver.isAllowedExternalUri(uri)) {
      S1SnackBar.show(context, message: '无法打开链接');
      return;
    }
    try {
      final ok = await forumWebLauncher(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
    } on Object {
      if (context.mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
    }
  }

  String get _message {
    if (error is ServerMaintenanceException) {
      return (error as ServerMaintenanceException).message;
    }
    return userFacingError(error);
  }
}
