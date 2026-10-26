class LoginRequiredException implements Exception {
  @override
  String toString() => 'LoginRequiredException';
}

class ServerMaintenanceException implements Exception {
  ServerMaintenanceException([this.message = '服务器维护中']);

  final String message;

  @override
  String toString() => message;
}

/// 服务端 5xx（Discuz System Error / 网关错误 / 安全校验拒绝）。
///
/// 与 [ServerMaintenanceException] 区分：后者是服务器主动给出的公告原文，
/// 这里只是把 5xx 的响应体压成一句可展示的原因。原因**不进主文案**，
/// 只作为 [diagnosticDetail] 供错误页的「查看详情」折叠区展示。
class ServerBusyException implements Exception {
  const ServerBusyException({
    required this.statusCode,
    this.detail = '',
    this.securityRejected = false,
  });

  final int statusCode;

  /// 压缩后的响应体摘要（可能为空）。
  final String detail;

  /// 是否被 Discuz 安全校验拦截（非普通网关错误）。
  final bool securityRejected;

  /// 用户可见文案：不暴露服务端实现细节。
  String get message {
    if (securityRejected) return '论坛拒绝了本次请求，请稍后重试';
    return '服务器暂时不可用，请稍后再试';
  }

  /// 折叠区里的技术细节（HTTP 状态 + 服务端原文）。
  String get diagnosticDetail {
    final buffer = StringBuffer('HTTP $statusCode');
    if (securityRejected) {
      buffer.write('\nDiscuz 安全校验拒绝（请求含非法字符）');
    }
    if (detail.isNotEmpty) buffer.write('\n$detail');
    return buffer.toString();
  }

  @override
  String toString() => message;
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
