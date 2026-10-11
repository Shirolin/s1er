import '../services/settings_store.dart';

/// 一次「自动应用更新失败（已回滚）」的记录：失败版本 + 原因。
///
/// 冷启动自动检查据此对该版本退避；手动检查仍展示 [reason]。
class BlockedUpdate {
  const BlockedUpdate({required this.version, this.reason});

  final String version;
  final String? reason;
}

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

  /// 读取上次应用失败的记录；无记录返回 null。
  static BlockedUpdate? blocked(SettingsStore? store) {
    final raw = store?.get<String>(blockedVersionKey);
    final version = raw?.trim();
    if (version == null || version.isEmpty) return null;
    final reasonRaw = store?.get<String>(blockedReasonKey);
    final reason = reasonRaw?.trim();
    return BlockedUpdate(
      version: version,
      reason: (reason == null || reason.isEmpty) ? null : reason,
    );
  }

  /// 记录一次应用失败（版本 + 原因），供自动检查退避。
  static void setBlocked(SettingsStore? store, BlockedUpdate blocked) {
    final version = blocked.version.trim();
    if (version.isEmpty) return;
    store?.put(blockedVersionKey, version);
    store?.put(blockedReasonKey, blocked.reason?.trim() ?? '');
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
