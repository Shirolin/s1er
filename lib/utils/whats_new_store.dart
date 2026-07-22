import '../services/settings_store.dart';
import 'semver.dart';

/// What's New 本地状态（SettingsStore 辅助 key，不进 AppSettings / L1 备份）。
abstract class WhatsNewStore {
  static const seenVersionKey = 'whats_new_seen_version';

  /// 略晚于升级检查，避免与升级 Dialog 抢同一帧。
  static const startupDelay = Duration(milliseconds: 3500);

  static String? seenVersion(SettingsStore? store) {
    final raw = store?.get<String>(seenVersionKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static void setSeenVersion(SettingsStore? store, String version) {
    store?.put(seenVersionKey, version.trim());
  }
}

/// 冷启动对「是否弹 What's New」的判定。
enum WhatsNewDecision {
  /// 无需动作（已读当前或更新）。
  none,

  /// 首次安装：静默写入已读，不弹窗。
  markSeenSilent,

  /// 版本升级：应展示 `(seen, current]` 的说明。
  showPrompt,
}

WhatsNewDecision decideWhatsNew({
  required String? seenVersion,
  required String currentVersion,
}) {
  final current = currentVersion.trim();
  if (current.isEmpty) return WhatsNewDecision.none;

  final seen = seenVersion?.trim();
  if (seen == null || seen.isEmpty) {
    return WhatsNewDecision.markSeenSilent;
  }

  try {
    if (Semver.isLessThan(seen, current)) {
      return WhatsNewDecision.showPrompt;
    }
  } on FormatException {
    // 旧值损坏：当作首次，静默对齐到当前版本。
    return WhatsNewDecision.markSeenSilent;
  }
  return WhatsNewDecision.none;
}
