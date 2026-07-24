import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../models/app_exceptions.dart';
import '../models/app_update_manifest.dart';
import '../services/settings_store.dart';
import '../services/talker.dart';
import '../services/update_check_service.dart';
import '../utils/semver.dart';
import '../utils/update_prompt_store.dart';
import 'settings_provider.dart';
import 'talker_provider.dart';

enum UpdateAvailability { force, optional, upToDate }

/// 一次检查的评估结果（含是否应弹出 Dialog）。
class UpdateEvaluation {
  const UpdateEvaluation({
    required this.availability,
    required this.localVersion,
    required this.manifest,
    required this.downloadUrl,
    required this.shouldShowDialog,
    this.userMessage,
    this.netdiskUrl = '',
    this.canInAppDownload = false,
  });

  final UpdateAvailability availability;
  final String localVersion;
  final AppUpdateManifest manifest;
  final String downloadUrl;

  /// 白名单校验后的网盘外链；空则不展示网盘按钮。
  final String netdiskUrl;

  /// Android 非 Play 且有合法 APK 直链时为 true。
  final bool canInAppDownload;

  /// 是否应展示升级 Dialog（启动自动 / 手动均适用）。
  final bool shouldShowDialog;

  /// 手动检查时无 Dialog 时的 SnackBar 文案；启动静默时可为 null。
  final String? userMessage;

  String? get netdiskHint {
    final hint = manifest.channels.netdiskHint?.trim();
    if (hint == null || hint.isEmpty) return null;
    return hint;
  }

  bool get hasNetdisk => netdiskUrl.isNotEmpty;

  bool get isUpdate =>
      availability == UpdateAvailability.force ||
      availability == UpdateAvailability.optional;
}

/// 纯函数：比较本地版本与清单，结合忽略 / 冷却决定是否弹窗。
UpdateEvaluation evaluateUpdate({
  required String localVersion,
  required AppUpdateManifest manifest,
  required String downloadUrl,
  String? ignoredVersion,
  String? lastPromptVersion,
  int? lastPromptMs,
  required DateTime now,
  required bool manual,
  Duration cooldown = UpdatePromptStore.cooldown,
  String netdiskUrl = '',
  bool canInAppDownload = false,
}) {
  final local = localVersion.trim();

  if (Semver.isLessThan(local, manifest.minSupported)) {
    return UpdateEvaluation(
      availability: UpdateAvailability.force,
      localVersion: local,
      manifest: manifest,
      downloadUrl: downloadUrl,
      netdiskUrl: netdiskUrl,
      canInAppDownload: canInAppDownload,
      shouldShowDialog: true,
    );
  }

  if (!Semver.isLessThan(local, manifest.latest)) {
    return UpdateEvaluation(
      availability: UpdateAvailability.upToDate,
      localVersion: local,
      manifest: manifest,
      downloadUrl: downloadUrl,
      netdiskUrl: netdiskUrl,
      canInAppDownload: canInAppDownload,
      shouldShowDialog: false,
      userMessage: manual ? '已是最新版本' : null,
    );
  }

  // optional
  final ignored = ignoredVersion?.trim();
  if (ignored != null &&
      ignored.isNotEmpty &&
      Semver.compare(ignored, manifest.latest) == 0) {
    return UpdateEvaluation(
      availability: UpdateAvailability.optional,
      localVersion: local,
      manifest: manifest,
      downloadUrl: downloadUrl,
      netdiskUrl: netdiskUrl,
      canInAppDownload: canInAppDownload,
      shouldShowDialog: false,
      userMessage: manual ? '已忽略此版本的更新提示' : null,
    );
  }

  if (!manual && lastPromptMs != null) {
    final isSameVersion = lastPromptVersion == null ||
        lastPromptVersion.trim().isEmpty ||
        lastPromptVersion.trim() == manifest.latest.trim();
    if (isSameVersion) {
      final elapsed = now.millisecondsSinceEpoch - lastPromptMs;
      if (elapsed >= 0 && elapsed < cooldown.inMilliseconds) {
        return UpdateEvaluation(
          availability: UpdateAvailability.optional,
          localVersion: local,
          manifest: manifest,
          downloadUrl: downloadUrl,
          netdiskUrl: netdiskUrl,
          canInAppDownload: canInAppDownload,
          shouldShowDialog: false,
        );
      }
    }
  }

  return UpdateEvaluation(
    availability: UpdateAvailability.optional,
    localVersion: local,
    manifest: manifest,
    downloadUrl: downloadUrl,
    netdiskUrl: netdiskUrl,
    canInAppDownload: canInAppDownload,
    shouldShowDialog: true,
  );
}

class UpdateCheckState {
  const UpdateCheckState({
    this.isChecking = false,
    this.pendingPrompt,
    this.autoCheckStarted = false,
    this.startupSettled = false,
  });

  final bool isChecking;

  /// 待展示的升级 Dialog（由 [UpdatePromptHost] 消费后 clear）。
  final UpdateEvaluation? pendingPrompt;

  /// 本 session 是否已触发过冷启动检查。
  final bool autoCheckStarted;

  /// 冷启动检查已结束（成功或失败）；供 What's New 等待，避免抢弹窗。
  final bool startupSettled;

  UpdateCheckState copyWith({
    bool? isChecking,
    UpdateEvaluation? pendingPrompt,
    bool clearPendingPrompt = false,
    bool? autoCheckStarted,
    bool? startupSettled,
  }) {
    return UpdateCheckState(
      isChecking: isChecking ?? this.isChecking,
      pendingPrompt:
          clearPendingPrompt ? null : (pendingPrompt ?? this.pendingPrompt),
      autoCheckStarted: autoCheckStarted ?? this.autoCheckStarted,
      startupSettled: startupSettled ?? this.startupSettled,
    );
  }
}

final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService();
});

class UpdateCheckNotifier extends Notifier<UpdateCheckState> {
  @override
  UpdateCheckState build() => const UpdateCheckState();

  SettingsStore? _tryStore() {
    try {
      return ref.read(settingsStoreProvider);
    } on Object {
      return null;
    }
  }

  UpdateCheckService get _service => ref.read(updateCheckServiceProvider);

  /// 冷启动：延迟后检查一次；失败静默。
  Future<void> runStartupCheck({
    Duration delay = UpdatePromptStore.startupDelay,
    DateTime Function()? clock,
  }) async {
    if (state.autoCheckStarted) return;
    state = state.copyWith(autoCheckStarted: true);

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!ref.mounted) return;

    try {
      final evaluation = await _evaluate(manual: false, clock: clock);
      if (!ref.mounted) return;
      if (evaluation.shouldShowDialog) {
        state = state.copyWith(pendingPrompt: evaluation);
      }
    } on UpdateCheckException catch (e) {
      // 启动静默失败（常见：私有仓库 raw 清单 404）；不按崩溃级别打 exception。
      talker.warning('Startup update check skipped: ${e.message}');
    } on Object catch (e, st) {
      talker.handle(e, st, 'Startup update check failed');
    } finally {
      if (ref.mounted) {
        state = state.copyWith(startupSettled: true);
      }
    }
  }

  /// 手动检查：忽略冷却；返回评估结果供 UI 弹 Dialog / SnackBar。
  /// 不写入 [UpdateCheckState.pendingPrompt]（避免与启动 Host 竞态双弹）。
  Future<UpdateEvaluation> checkManual({DateTime Function()? clock}) async {
    if (state.isChecking) {
      throw const UpdateCheckException('正在检查更新…');
    }
    state = state.copyWith(isChecking: true);
    try {
      final evaluation = await _evaluate(manual: true, clock: clock);
      if (!ref.mounted) return evaluation;
      state = state.copyWith(isChecking: false);
      return evaluation;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isChecking: false);
      }
      rethrow;
    }
  }

  Future<UpdateEvaluation> _evaluate({
    required bool manual,
    DateTime Function()? clock,
  }) async {
    final now = clock?.call() ?? DateTime.now();
    final info = await ref.read(packageInfoProvider.future);
    if (!ref.mounted) {
      throw const UpdateCheckException('检查已取消');
    }
    final manifest = await _service.fetchManifest();
    if (!ref.mounted) {
      throw const UpdateCheckException('检查已取消');
    }
    final store = _tryStore();
    final downloadUrl = UpdateCheckService.resolveDownloadUrl(
      manifest,
      distribution: EnvConfig.distribution,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
    final netdiskUrl = UpdateCheckService.resolveNetdiskUrl(manifest);
    final canInApp = UpdateCheckService.canInAppAndroidDownload(
      manifest: manifest,
      distribution: EnvConfig.distribution,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
    return evaluateUpdate(
      localVersion: info.version,
      manifest: manifest,
      downloadUrl: downloadUrl,
      netdiskUrl: netdiskUrl,
      canInAppDownload: canInApp,
      ignoredVersion: UpdatePromptStore.ignoredVersion(store),
      lastPromptVersion: UpdatePromptStore.lastPromptVersion(store),
      lastPromptMs: UpdatePromptStore.lastPromptMs(store),
      now: now,
      manual: manual,
    );
  }

  void clearPendingPrompt() {
    state = state.copyWith(clearPendingPrompt: true);
  }

  /// 测试用：模拟启动已结算且（可选）有待展示升级 Dialog。
  @visibleForTesting
  void debugSetStartupPrompt({UpdateEvaluation? pendingPrompt}) {
    state = UpdateCheckState(
      autoCheckStarted: true,
      startupSettled: true,
      pendingPrompt: pendingPrompt,
    );
  }

  /// Dialog 已展示或关闭（含稍后）：写入冷却时间戳与目标版本号。
  void markPromptInteracted({
    String? targetVersion,
    DateTime Function()? clock,
  }) {
    final rawVersion = targetVersion ?? state.pendingPrompt?.manifest.latest;
    final version = rawVersion?.trim() ?? '';
    if (version.isEmpty) {
      talker.warning(
        'markPromptInteracted called without a valid target version',
      );
      return;
    }
    final now = clock?.call() ?? DateTime.now();
    UpdatePromptStore.setLastPrompt(
      store: _tryStore(),
      version: version,
      ms: now.millisecondsSinceEpoch,
    );
  }

  void ignoreVersion(String version) {
    UpdatePromptStore.setIgnoredVersion(_tryStore(), version);
    markPromptInteracted(targetVersion: version);
    clearPendingPrompt();
  }
}

final updateCheckProvider =
    NotifierProvider<UpdateCheckNotifier, UpdateCheckState>(
  UpdateCheckNotifier.new,
);

/// 在应用根 [ref.watch]，冷启动延迟触发升级检查。
final updateCheckCoordinatorProvider = Provider<void>((ref) {
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    unawaited(ref.read(updateCheckProvider.notifier).runStartupCheck());
  });
});
