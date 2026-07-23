import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/update_check_provider.dart';
import '../providers/update_download_provider.dart';
import '../utils/post_link_resolver.dart';
import '../utils/s1_snack_bar.dart';
import '../utils/update_prompt_store.dart';

typedef ExternalUrlLauncher = Future<bool> Function(
  Uri uri, {
  LaunchMode mode,
});

typedef UpdatePromptClosed = void Function(
  UpdatePromptCloseReason reason, {
  String? ignoredVersion,
});

/// M3 升级提醒：Android 可应用内下载；网盘为国内备选；其它平台外链。
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required UpdateEvaluation evaluation,
  required UpdatePromptClosed onPromptClosed,
  ExternalUrlLauncher? launchUrlFn,
  ProviderContainer? container,
}) async {
  final launch = launchUrlFn ??
      ((Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) =>
          launchUrl(uri, mode: mode));

  // Capture container before the dialog so reset still works after pop.
  ProviderContainer? captured;
  try {
    captured = container ?? ProviderScope.containerOf(context);
  } on Object {
    captured = container;
  }

  final force = evaluation.availability == UpdateAvailability.force;
  var closeReason = UpdatePromptCloseReason.later;
  String? ignoredVersion;

  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) {
      final dialog = _AppUpdateDialogBody(
        evaluation: evaluation,
        launchUrlFn: launch,
        onRequestClose: (reason, {String? version}) {
          closeReason = reason;
          ignoredVersion = version;
          Navigator.of(ctx).pop();
        },
      );
      final wrapped = PopScope(
        canPop: !force,
        child: dialog,
      );
      if (container != null) {
        return UncontrolledProviderScope(
          container: container,
          child: wrapped,
        );
      }
      return wrapped;
    },
  );

  try {
    captured?.read(updateDownloadProvider.notifier).reset();
  } on Object {
    // container 可能已 dispose
  }

  onPromptClosed(closeReason, ignoredVersion: ignoredVersion);
}

class _AppUpdateDialogBody extends ConsumerStatefulWidget {
  const _AppUpdateDialogBody({
    required this.evaluation,
    required this.launchUrlFn,
    required this.onRequestClose,
  });

  final UpdateEvaluation evaluation;
  final ExternalUrlLauncher launchUrlFn;
  final void Function(
    UpdatePromptCloseReason reason, {
    String? version,
  }) onRequestClose;

  @override
  ConsumerState<_AppUpdateDialogBody> createState() =>
      _AppUpdateDialogBodyState();
}

class _AppUpdateDialogBodyState extends ConsumerState<_AppUpdateDialogBody>
    with WidgetsBindingObserver {
  UpdateEvaluation get evaluation => widget.evaluation;

  var _observingLifecycle = false;
  var _autoRetrying = false;

  bool get _useInApp =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      evaluation.canInAppDownload;

  @override
  void dispose() {
    _stopLifecycleObserver();
    super.dispose();
  }

  void _startLifecycleObserver() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  void _stopLifecycleObserver() {
    if (!_observingLifecycle) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingLifecycle = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_autoRetrying) return;
    final phase = ref.read(updateDownloadProvider).phase;
    if (phase != UpdateDownloadPhase.needsPermission) return;
    unawaited(_tryResumeAfterPermission());
  }

  Future<void> _tryResumeAfterPermission() async {
    if (_autoRetrying || !mounted) return;
    _autoRetrying = true;
    try {
      final installer = ref.read(appUpdateInstallerProvider);
      final canInstall = await installer.canInstallPackages();
      if (!mounted || !canInstall) return;
      await ref.read(updateDownloadProvider.notifier).retry(evaluation);
    } finally {
      _autoRetrying = false;
    }
  }

  Future<void> _openExternal(String url, {String? snackAfter}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !PostLinkResolver.isAllowedExternalUri(uri)) {
      if (mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
      return;
    }
    try {
      final ok = await widget.launchUrlFn(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
        return;
      }
      if (snackAfter != null && mounted) {
        S1SnackBar.show(context, message: snackAfter);
      }
    } on Object {
      if (mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
    }
  }

  Future<void> _openNetdisk() async {
    final hint = evaluation.netdiskHint;
    await _openExternal(
      evaluation.netdiskUrl,
      snackAfter: hint == null ? '已打开网盘' : '已打开网盘；若需要提取码请查看上方说明',
    );
  }

  Future<void> _openBrowserDownload() async {
    final url = evaluation.downloadUrl;
    if (url.isEmpty) {
      if (mounted) {
        S1SnackBar.show(context, message: '无法打开链接');
      }
      return;
    }
    await _openExternal(url);
  }

  Future<void> _startInApp() async {
    final notifier = ref.read(updateDownloadProvider.notifier);
    try {
      await notifier.startAndroidUpdate(evaluation);
      final phase = ref.read(updateDownloadProvider).phase;
      if (phase == UpdateDownloadPhase.idle && mounted) {
        widget.onRequestClose(UpdatePromptCloseReason.later);
      }
    } on Object catch (e) {
      if (mounted) {
        S1SnackBar.show(context, message: '更新失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final download = ref.watch(updateDownloadProvider);
    final force = evaluation.availability == UpdateAvailability.force;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final failed = download.phase == UpdateDownloadPhase.failed;
    final cancelled = download.phase == UpdateDownloadPhase.cancelled;
    final needsPermission =
        download.phase == UpdateDownloadPhase.needsPermission;
    final downloading = download.phase == UpdateDownloadPhase.downloading ||
        download.phase == UpdateDownloadPhase.installing;

    if (needsPermission) {
      _startLifecycleObserver();
    } else {
      _stopLifecycleObserver();
    }

    final title = failed
        ? '下载失败'
        : cancelled
            ? '已取消下载'
            : needsPermission
                ? '需要安装权限'
                : (force ? '需要更新' : '发现新版本');

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: _buildContent(
          scheme: scheme,
          textTheme: textTheme,
          download: download,
          force: force,
          failed: failed,
          cancelled: cancelled,
          needsPermission: needsPermission,
          downloading: downloading,
        ),
      ),
      actions: _buildActions(
        download: download,
        force: force,
        failed: failed,
        cancelled: cancelled,
        needsPermission: needsPermission,
        downloading: downloading,
      ),
    );
  }

  Widget _buildContent({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required UpdateDownloadState download,
    required bool force,
    required bool failed,
    required bool cancelled,
    required bool needsPermission,
    required bool downloading,
  }) {
    final notes = evaluation.manifest.notes.trim();
    final hint = evaluation.netdiskHint;

    if (downloading) {
      final label = download.phase == UpdateDownloadPhase.installing
          ? '正在调起安装…'
          : '正在下载… ${(download.progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: textTheme.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: download.phase == UpdateDownloadPhase.installing
                ? null
                : download.progress,
          ),
          if (evaluation.hasNetdisk && hint != null) ...[
            const SizedBox(height: 12),
            Text(
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    if (needsPermission) {
      return Text(
        download.message ?? '请允许「安装未知应用」后返回继续更新。',
        style: textTheme.bodyMedium,
      );
    }

    if (failed || cancelled) {
      final buffer = StringBuffer(
        cancelled
            ? (download.message?.trim().isNotEmpty == true
                ? download.message!
                : '已取消下载。')
            : (download.message?.trim().isNotEmpty == true
                ? '${download.message}\n\n直链下载失败，可能是网络受限。'
                : '直链下载失败，可能是网络受限。'),
      );
      if (!cancelled) {
        if (evaluation.hasNetdisk) {
          buffer.write('可用网盘获取安装包。');
        } else {
          buffer.write('可尝试浏览器打开下载页。');
        }
      }
      if (hint != null) {
        buffer.write('\n\n');
        buffer.write(hint);
      }
      return Text(buffer.toString(), style: textTheme.bodyMedium);
    }

    final buffer = StringBuffer(
      force
          ? '当前版本过旧，请更新到 ${evaluation.manifest.latest} 以继续获得完整支持。'
          : '发现新版本 ${evaluation.manifest.latest}（当前 ${evaluation.localVersion}）。',
    );
    if (notes.isNotEmpty) {
      buffer.write('\n\n');
      buffer.write(notes);
    }
    if (evaluation.hasNetdisk && hint != null) {
      buffer.write('\n\n');
      buffer.write(hint);
    }
    return Text(buffer.toString(), style: textTheme.bodyMedium);
  }

  List<Widget> _buildActions({
    required UpdateDownloadState download,
    required bool force,
    required bool failed,
    required bool cancelled,
    required bool needsPermission,
    required bool downloading,
  }) {
    final actions = <Widget>[];

    if (downloading) {
      actions.add(
        TextButton(
          onPressed: () {
            ref.read(updateDownloadProvider.notifier).cancelDownload();
          },
          child: const Text('取消'),
        ),
      );
      if (evaluation.hasNetdisk) {
        actions.add(
          TextButton(
            onPressed: () async {
              ref.read(updateDownloadProvider.notifier).cancelDownload();
              await _openNetdisk();
            },
            child: const Text('网盘下载'),
          ),
        );
      }
      return actions;
    }

    if (needsPermission) {
      if (!force) {
        actions.add(
          TextButton(
            onPressed: () =>
                widget.onRequestClose(UpdatePromptCloseReason.later),
            child: const Text('关闭'),
          ),
        );
      }
      actions.add(
        FilledButton(
          onPressed: () async {
            await ref
                .read(updateDownloadProvider.notifier)
                .openInstallPermissionSettings();
          },
          child: const Text('去授权'),
        ),
      );
      actions.add(
        FilledButton(
          onPressed: () =>
              ref.read(updateDownloadProvider.notifier).retry(evaluation),
          child: const Text('继续'),
        ),
      );
      return actions;
    }

    if (failed || cancelled) {
      actions.add(
        TextButton(
          onPressed: () =>
              ref.read(updateDownloadProvider.notifier).retry(evaluation),
          child: const Text('重试'),
        ),
      );
      if (evaluation.hasNetdisk) {
        actions.add(
          TextButton(
            onPressed: _openBrowserDownload,
            child: const Text('浏览器打开'),
          ),
        );
        actions.add(
          FilledButton(
            onPressed: () async {
              await _openNetdisk();
              if (mounted) {
                widget.onRequestClose(UpdatePromptCloseReason.later);
              }
            },
            child: const Text('网盘下载'),
          ),
        );
      } else {
        actions.add(
          FilledButton(
            onPressed: () async {
              await _openBrowserDownload();
              if (mounted) {
                widget.onRequestClose(UpdatePromptCloseReason.later);
              }
            },
            child: const Text('浏览器打开'),
          ),
        );
      }
      return actions;
    }

    // 初始态
    if (!force) {
      actions.add(
        TextButton(
          onPressed: () => widget.onRequestClose(
            UpdatePromptCloseReason.ignored,
            version: evaluation.manifest.latest,
          ),
          child: const Text('忽略此版'),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () => widget.onRequestClose(UpdatePromptCloseReason.later),
          child: const Text('稍后'),
        ),
      );
    }

    if (evaluation.hasNetdisk) {
      actions.add(
        TextButton(
          onPressed: () async {
            await _openNetdisk();
            if (mounted) {
              widget.onRequestClose(UpdatePromptCloseReason.later);
            }
          },
          child: const Text('网盘下载'),
        ),
      );
    }

    if (_useInApp) {
      actions.add(
        FilledButton(
          onPressed: _startInApp,
          child: const Text('立即更新'),
        ),
      );
    } else {
      actions.add(
        FilledButton(
          onPressed: () async {
            await _openBrowserDownload();
            if (mounted) {
              widget.onRequestClose(UpdatePromptCloseReason.later);
            }
          },
          child: const Text('去更新'),
        ),
      );
    }

    return actions;
  }
}
