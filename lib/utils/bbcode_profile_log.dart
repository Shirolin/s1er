import 'package:flutter/foundation.dart';

import '../services/talker.dart';

/// `[bbcode-profile]` 打点输出：控制台 + Talker 各写一份。
///
/// 放在 `lib/utils/` 是为了守住「widgets/screens 不得直接 import
/// services」的架构守卫（test/architecture/guardrails_test.dart）。
/// Talker 版本让真机 release/profile 下也能在 App 内
/// TalkerScreen（设置 → 关于 → 版本行点 5 下）看到打点。
void logBbcodeProfile(String line) {
  debugPrint(line);
  talker.debug(line);
}
