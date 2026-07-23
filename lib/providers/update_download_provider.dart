import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_exceptions.dart';
import '../services/app_update_downloader.dart';
import '../services/app_update_installer.dart';
import '../services/talker.dart';
import 'update_check_provider.dart';

enum UpdateDownloadPhase {
  idle,
  needsPermission,
  downloading,
  installing,
  failed,
  cancelled,
}

class UpdateDownloadState {
  const UpdateDownloadState({
    this.phase = UpdateDownloadPhase.idle,
    this.progress = 0,
    this.message,
  });

  final UpdateDownloadPhase phase;
  final double progress;
  final String? message;

  bool get isBusy =>
      phase == UpdateDownloadPhase.downloading ||
      phase == UpdateDownloadPhase.installing;

  UpdateDownloadState copyWith({
    UpdateDownloadPhase? phase,
    double? progress,
    String? message,
    bool clearMessage = false,
  }) {
    return UpdateDownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

final appUpdateDownloaderProvider = Provider<AppUpdateDownloader>((ref) {
  return AppUpdateDownloader();
});

final appUpdateInstallerProvider = Provider<AppUpdateInstaller>((ref) {
  return AppUpdateInstaller();
});

class UpdateDownloadNotifier extends Notifier<UpdateDownloadState> {
  @override
  UpdateDownloadState build() => const UpdateDownloadState();

  AppUpdateDownloader get _downloader => ref.read(appUpdateDownloaderProvider);
  AppUpdateInstaller get _installer => ref.read(appUpdateInstallerProvider);

  void reset() {
    _downloader.cancel();
    state = const UpdateDownloadState();
  }

  void cancelDownload() {
    _downloader.cancel();
    state = state.copyWith(
      phase: UpdateDownloadPhase.cancelled,
      message: '已取消下载',
    );
  }

  /// Android 应用内下载并调起安装；非目标平台抛错由 UI 改走外链。
  Future<void> startAndroidUpdate(UpdateEvaluation evaluation) async {
    if (!evaluation.canInAppDownload) {
      throw const UpdateCheckException('当前渠道不支持应用内下载');
    }
    if (!_installer.isSupported) {
      throw const UpdateCheckException('当前平台不支持应用内安装');
    }

    final canInstall = await _installer.canInstallPackages();
    if (!ref.mounted) return;
    if (!canInstall) {
      state = state.copyWith(
        phase: UpdateDownloadPhase.needsPermission,
        message: '需要允许安装未知应用才能继续',
        clearMessage: false,
      );
      return;
    }

    await _downloadAndInstall(evaluation);
  }

  Future<void> openInstallPermissionSettings() async {
    await _installer.openInstallPermissionSettings();
  }

  /// 授权后继续（或失败态重试）。
  Future<void> retry(UpdateEvaluation evaluation) async {
    if (state.isBusy) return;
    await startAndroidUpdate(evaluation);
  }

  Future<void> _downloadAndInstall(UpdateEvaluation evaluation) async {
    final apkUrls = evaluation.apkDownloadUrls;
    if (apkUrls.isEmpty) {
      state = state.copyWith(
        phase: UpdateDownloadPhase.failed,
        message: '没有可用的下载地址',
      );
      return;
    }

    state = state.copyWith(
      phase: UpdateDownloadPhase.downloading,
      progress: 0,
      clearMessage: true,
    );

    try {
      final result = await _downloader.downloadApk(
        urls: apkUrls,
        versionLabel: evaluation.manifest.latest,
        onProgress: (p) {
          if (!ref.mounted) return;
          if (state.phase != UpdateDownloadPhase.downloading) return;
          state = state.copyWith(progress: p);
        },
      );
      if (!ref.mounted) return;

      state = state.copyWith(
        phase: UpdateDownloadPhase.installing,
        progress: 1,
      );
      await _installer.installApk(result.filePath);
      if (!ref.mounted) return;
      // 安装器已调起；保持 installing，由 Dialog 关闭。
      state = state.copyWith(phase: UpdateDownloadPhase.idle, progress: 1);
    } on UpdateCheckException catch (e) {
      if (!ref.mounted) return;
      if (e.message.contains('取消')) {
        state = state.copyWith(
          phase: UpdateDownloadPhase.cancelled,
          message: e.message,
        );
        return;
      }
      talker.warning('In-app update failed: ${e.message}');
      state = state.copyWith(
        phase: UpdateDownloadPhase.failed,
        message: e.message,
      );
    } on Object catch (e, st) {
      talker.handle(e, st, 'In-app update failed');
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: UpdateDownloadPhase.failed,
        message: '更新失败',
      );
    }
  }
}

final updateDownloadProvider =
    NotifierProvider<UpdateDownloadNotifier, UpdateDownloadState>(
  UpdateDownloadNotifier.new,
);
