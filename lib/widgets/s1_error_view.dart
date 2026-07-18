import 'package:flutter/material.dart';
import '../models/app_exceptions.dart';
import '../utils/error_handler.dart';

class S1ErrorView extends StatelessWidget {
  const S1ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.onLogin,
  });
  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onLogin;

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
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
          ],
        ),
      ),
    );
  }

  String get _message {
    if (error is ServerMaintenanceException) {
      return (error as ServerMaintenanceException).message;
    }
    return userFacingError(error);
  }
}
