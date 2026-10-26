/// Discuz 5xx 错误页的可用信息提取。
///
/// S1 在网关错误 / System Error / 安全校验时会返回整页 HTML，客户端原来的
/// 通用文案「服务器暂时不可用」把真正原因全部丢掉。这里只做两件事：
/// 1. 把 HTML 压成一段可展示的短文本（去脚本/样式/标签、折叠空白）；
/// 2. 判断是否为 Discuz 安全校验拒绝（`request_tainting` / 「非法字符」）。
library;

/// 压成一行短文本，默认截断 160 字（够放进错误页副标题）。
///
/// Discuz 的 System Error 页把真正原因排在 `Time / IP / BackTraceID` 之后，
/// 直接从头截断只会剩标题，因此先定位 `BackTraceID`，再取到 `PHP Debug`
/// 之前的异常信息（如 `in_array(): Argument #2 ... null given`）。
String summarizeErrorBody(String body, {int maxChars = 160}) {
  var text = body
      .replaceAll(
        RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final backtrace = RegExp(r'BackTraceID:\s*\S+\s*').firstMatch(text);
  if (backtrace != null) {
    var reason = text.substring(backtrace.end);
    final debugStart = reason.indexOf('PHP Debug');
    if (debugStart > 0) reason = reason.substring(0, debugStart);
    if (reason.trim().isNotEmpty) text = reason.trim();
  }

  if (text.length > maxChars) {
    text = '${text.substring(0, maxChars)}…';
  }
  return text;
}

/// 是否为 Discuz 安全校验（XSS / 非法字符）拦截，而非普通网关错误。
bool looksLikeDiscuzSecurityReject(String body) {
  return body.contains('request_tainting') || body.contains('非法字符');
}
