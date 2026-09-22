import 'dart:convert';

/// 论坛服务器官方公告原文提取。
///
/// 真相源是论坛服务器：只搬运响应里下发的原文；任何通道抽不到内容都
/// 返回 `null`，由调用方维持通用文案——app 不得代服务器拟制公告。
///
/// 通道取舍参考同类第三方客户端：
/// - JSON 顶层 `error` / `Variables.error`：S1-Orange（request.ets）
/// - `#messagetext` / `.alert_error` 提示页：S1-Next（HtmlDataWrapper）
/// - 网关错误页 `div.info > li`：S1-Next（ErrorUtil，仅用于错误响应体）
class ServerNotice {
  ServerNotice._();

  /// JSON 响应中的官方错误 / 公告文本。
  ///
  /// 对齐 S1-Orange：存在 `Variables` 时只认 `Variables.error`，否则认
  /// 顶层 `error`；`to_login` 与空串视为无公告。
  static String? fromJson(Map<dynamic, dynamic> json) {
    final variables = json['Variables'];
    if (variables is Map) {
      return _clean(variables['error']);
    }
    return _clean(json['error']);
  }

  /// 成功响应体（JSON / HTML）中的官方文本。
  ///
  /// HTML 只认 Discuz 提示页专属结构（`#messagetext` / `.alert_error`），
  /// 普通页面不会命中，避免误报。
  static String? fromResponseBody(dynamic data) =>
      _fromBody(data, gateway: false);

  /// 非 2xx 错误体中的官方文本。
  ///
  /// 在 [fromResponseBody] 之上追加网关错误页结构 `div.info > li`
  ///（参考 S1-Next 对 errorBody 的提取）。
  static String? fromErrorBody(dynamic data) => _fromBody(data, gateway: true);

  /// HTML 提示页中的官方文本；抽不到返回 `null`。
  static String? fromHtml(String html, {bool gateway = false}) {
    for (final pattern in _patterns(gateway: gateway)) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final raw = match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (raw.isNotEmpty) return raw;
    }
    return null;
  }

  static String? _fromBody(dynamic data, {required bool gateway}) {
    if (data == null) return null;
    if (data is Map) return fromJson(data);
    if (data is List<int>) return null; // 图片等二进制响应
    final text = data.toString();
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return fromJson(decoded);
      } on FormatException {
        return null;
      }
      return null;
    }
    if (trimmed.startsWith('<') || text.contains('<div')) {
      return fromHtml(text, gateway: gateway);
    }
    return null;
  }

  static String? _clean(dynamic raw) {
    if (raw == null) return null;
    final message = raw.toString().trim();
    if (message.isEmpty || message == 'to_login') return null;
    return message;
  }

  static List<RegExp> _patterns({required bool gateway}) {
    final patterns = [
      // Discuz 提示以 <p> 包裹（真实 S1 HTML 可能在 </div> 前就接 <script>）。
      RegExp(
        r'<div\s+id="messagetext"[^>]*>\s*<p>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<div[^>]*class="[^"]*alert_error[^"]*"[^>]*>\s*<p>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      // 无 <p> 包裹时回退到 div 内容本身。
      RegExp(
        r'<div\s+id="messagetext"[^>]*>(.*?)</div>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<div[^>]*class="[^"]*alert_error[^"]*"[^>]*>(.*?)</div>',
        caseSensitive: false,
        dotAll: true,
      ),
    ];
    if (gateway) {
      patterns.add(
        RegExp(
          r'<div[^>]*class="info(?:\s[^"]*)?"[^>]*>\s*(?:<ul[^>]*>\s*)?'
          r'<li[^>]*>(.*?)</li>',
          caseSensitive: false,
          dotAll: true,
        ),
      );
    }
    return patterns;
  }
}
