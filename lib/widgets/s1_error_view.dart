import 'package:flutter/material.dart';
import 'package:dio/dio.dart' show DioException;
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

    final effective = unwrapServerNotice(error);
    final isLogin = effective is LoginRequiredException;
    final isMaintenance = effective is ServerMaintenanceException;
    // 技术细节默认折叠：普通用户只看到「加载失败 + 重试」，开发者可展开查看
    // 服务端原文（5xx 原因 / 未预期的异常类型）。
    final diagnostic = _diagnosticOf(effective);

    return Center(
      // 展开技术细节后内容可能超过一屏（尤其小屏 + 软键盘），必须可滚动。
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              isLogin
                  ? '当前 Stage1st 需要登录后查看论坛内容'
                  : _messageOf(
                      effective,
                    ),
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
            if (diagnostic != null) ...[
              const SizedBox(height: 20),
              _ErrorDiagnosticPanel(detail: diagnostic),
            ],
          ],
        ),
      ),
    );
  }

  /// 需要折叠展示的技术细节；null 表示无需展示。
  ///
  /// 只暴露服务端返回的原因与我们已知的异常类型，不带堆栈（堆栈进 Talker）。
  String? _diagnosticOf(Object effective) {
    if (effective is ServerBusyException) {
      return effective.diagnosticDetail;
    }
    if (effective is DioException) {
      final status = effective.response?.statusCode;
      return status == null ? null : 'HTTP $status';
    }
    return null;
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

  String _messageOf(Object effective) {
    if (effective is ServerMaintenanceException) {
      return effective.message;
    }
    return userFacingError(effective);
  }
}

/// 错误页底部的「详情」折叠区：默认收起，展开后暴露服务端原文。
class _ErrorDiagnosticPanel extends StatefulWidget {
  const _ErrorDiagnosticPanel({required this.detail});

  final String detail;

  @override
  State<_ErrorDiagnosticPanel> createState() => _ErrorDiagnosticPanelState();
}

class _ErrorDiagnosticPanelState extends State<_ErrorDiagnosticPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(_expanded ? '收起详情' : '查看详情'),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.detail,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
