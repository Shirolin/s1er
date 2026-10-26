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
/// 这里只是把 5xx 的响应体压成一句可展示的原因，避免一律显示
/// 「服务器暂时不可用」而丢掉真正信息。
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

  String get message {
    if (securityRejected) {
      return '论坛拒绝了本次请求（Discuz 安全校验：请求含非法字符）';
    }
    return detail.isEmpty ? 'S1 返回 $statusCode' : 'S1 返回 $statusCode：$detail';
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
