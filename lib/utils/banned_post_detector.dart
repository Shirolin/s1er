/// 检测 Discuz! 服务端下发的封禁/屏蔽脱敏特征。
class BannedPostDetector {
  BannedPostDetector._();

  static final RegExp _bannedPattern = RegExp(
    r'(?:提示[:：]\s*)?(?:作者被禁止或删除|该帖被管理员或版主屏蔽)(?:\s*内容自动屏蔽)?',
    caseSensitive: false,
  );

  /// 判断帖子正文 [message] 是否匹配 Discuz! 服务端封禁/屏蔽占位特征。
  static bool isBanned(String? message) {
    if (message == null || message.trim().isEmpty) return false;
    return _bannedPattern.hasMatch(message);
  }
}
