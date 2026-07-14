/// Discuz! / Mobile API 消息文案处理（对齐 S1-Next `DiscuzMessageFormatter`）。
library;

/// 多子句中文提示补全句号（S1-Next：含全角逗号且无句末句号时追加 `。`）。
String formatDiscuzMessage(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.contains('，') && !trimmed.endsWith('。')) {
    return '$trimmed。';
  }
  return trimmed;
}

/// 将登录接口的 `messageval` / `messagestr` 转为可展示文案。
///
/// Mobile API 失败时常返回裸 key（如 `mobile:login_invalid`），需映射为中文；
/// 若已有 Discuz 译文字符串则保留，并做 [formatDiscuzMessage] 句读处理。
String friendlyLoginError({
  String? messageval,
  String? messagestr,
}) {
  final valKey = normalizeDiscuzMessageKey(messageval);
  final str = messagestr?.trim() ?? '';
  final strKey = normalizeDiscuzMessageKey(str);

  if (str.isNotEmpty && !looksLikeDiscuzMessageKey(str)) {
    if (_hasUnsubstitutedPlaceholder(str)) {
      final fallback = _loginKeyMessages[valKey] ??
          _loginKeyMessages[strKey] ??
          '登录失败，请检查用户名、密码或安全提问后重试';
      return formatDiscuzMessage(fallback);
    }
    return formatDiscuzMessage(str);
  }

  final key = valKey.isNotEmpty ? valKey : strKey;
  final mapped = _loginKeyMessages[key];
  if (mapped != null) return formatDiscuzMessage(mapped);

  if (str.isNotEmpty && !looksLikeDiscuzMessageKey(str)) {
    return formatDiscuzMessage(str);
  }

  return '登录失败，请稍后重试';
}

/// 去掉 `mobile:` 前缀，便于对照语言包 key。
String normalizeDiscuzMessageKey(String? raw) {
  if (raw == null) return '';
  var text = raw.trim();
  if (text.startsWith('mobile:')) {
    text = text.substring('mobile:'.length);
  }
  return text;
}

/// 形如 `login_invalid` / `mobile:login_invalid` 的技术 key。
bool looksLikeDiscuzMessageKey(String text) {
  final key = normalizeDiscuzMessageKey(text);
  if (key.isEmpty) return false;
  return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key) && key.contains('_');
}

bool _hasUnsubstitutedPlaceholder(String text) =>
    RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}').hasMatch(text);

/// Discuz `lang_message.php` 登录相关文案（无模板变量的静态友好版）。
const Map<String, String> _loginKeyMessages = {
  'login_invalid': '登录失败，用户名、密码或安全提问不正确',
  'login_password_invalid': '抱歉，您输入的密码有误',
  'login_strike': '密码错误次数过多，请 15 分钟后重新登录',
  'login_question_empty': '请选择安全提问以及填写正确的答案',
  'login_question_invalid': '抱歉，安全提问答案填写错误',
  'login_seccheck2': '请输入验证码后继续登录',
  'profile_passwd_illegal': '密码为空或包含非法字符',
  'location_login_outofdate': '账号长期未登录已被冻结，请先验证邮箱',
  'location_login_force_qq': '您所在的用户组必须使用 QQ 账号登录',
  'location_login_force_mail': '您所在的用户组必须使用邮箱登录',
};
