import '../services/settings_store.dart';

/// 升级提醒本地状态（SettingsStore 辅助 key，不进 AppSettings / L1 备份）。
abstract class UpdatePromptStore {
  static const ignoredVersionKey = 'update_ignored_version';
  static const lastPromptMsKey = 'update_last_prompt_ms';

  static const cooldown = Duration(days: 3);
  static const startupDelay = Duration(seconds: 3);

  static String? ignoredVersion(SettingsStore? store) {
    final raw = store?.get<String>(ignoredVersionKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static void setIgnoredVersion(SettingsStore? store, String version) {
    store?.put(ignoredVersionKey, version.trim());
  }

  static int? lastPromptMs(SettingsStore? store) {
    final raw = store?.get(lastPromptMsKey);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  static const lastPromptVersionKey = 'update_last_prompt_version';

  /// 上次自动应用更新失败（已回滚）的版本与原因；自动检查据此退避。
  static const blockedVersionKey = 'update_blocked_version';
  static const blockedReasonKey = 'update_blocked_reason';

  static String? blockedVersion(SettingsStore? store) {
    final raw = store?.get<String>(blockedVersionKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? blockedReason(SettingsStore? store) {
    final raw = store?.get<String>(blockedReasonKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// [targetVersion] 是否正是上次应用失败、需要退避的版本。
  static bool isBlocked(SettingsStore? store, String targetVersion) {
    final blocked = blockedVersion(store);
    final target = targetVersion.trim();
    if (blocked == null || target.isEmpty) return false;
    return blocked == target;
  }

  static void setBlocked(
    SettingsStore? store, {
    required String version,
    required String reason,
  }) {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return;
    store?.put(blockedVersionKey, trimmed);
    store?.put(blockedReasonKey, reason.trim());
  }

  static void clearBlocked(SettingsStore? store) {
    store?.put(blockedVersionKey, null);
    store?.put(blockedReasonKey, null);
  }

  static String? lastPromptVersion(SettingsStore? store) {
    final raw = store?.get<String>(lastPromptVersionKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static bool isWithinCooldown({
    required SettingsStore? store,
    required String targetVersion,
    required DateTime now,
    Duration cooldown = cooldown,
  }) {
    final lastVersion = lastPromptVersion(store);
    if (lastVersion != null && lastVersion != targetVersion.trim()) {
      return false; // 新版本打破冷却！
    }
    final last = lastPromptMs(store);
    if (last == null) return false;
    final elapsed = now.millisecondsSinceEpoch - last;
    return elapsed >= 0 && elapsed < cooldown.inMilliseconds;
  }

  static void setLastPrompt({
    required SettingsStore? store,
    required String version,
    required int ms,
  }) {
    store?.put(lastPromptVersionKey, version.trim());
    store?.put(lastPromptMsKey, ms);
  }
}
