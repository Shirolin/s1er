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
