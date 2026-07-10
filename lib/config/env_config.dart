class EnvConfig {
  EnvConfig._();

  // ── 调试 ──────────────────────────────────────────────

  /// Talker 日志开关（默认 true）
  static const bool talkerEnabled = bool.fromEnvironment(
    'TALKER_ENABLED',
    defaultValue: true,
  );

  /// Talker Dio 日志级别：error / all（默认 error）
  /// - error: 仅记录请求错误（4xx/5xx/超时等）
  /// - all:   记录所有请求与响应
  static const String talkerLogLevel = String.fromEnvironment(
    'TALKER_LOG_LEVEL',
    defaultValue: 'error',
  );

  /// Talker 最大历史条数（默认 500）
  static const int talkerMaxHistory = int.fromEnvironment(
    'TALKER_MAX_HISTORY',
    defaultValue: 500,
  );

  // ── 网络 ──────────────────────────────────────────────

  /// Web 端 CORS 代理端口（默认 19080，需与 proxy_server 一致）
  static const int proxyPort = int.fromEnvironment(
    'PROXY_PORT',
    defaultValue: 19080,
  );

  /// 代理访问令牌（需与 proxy_server 启动时一致）
  static const String proxyAuthToken = String.fromEnvironment(
    'PROXY_AUTH_TOKEN',
    defaultValue: '',
  );

  /// 请求超时（秒，默认 20）
  static const int connectTimeoutSeconds = int.fromEnvironment(
    'CONNECT_TIMEOUT',
    defaultValue: 20,
  );

  /// 响应超时（秒，默认 30）
  static const int receiveTimeoutSeconds = int.fromEnvironment(
    'RECEIVE_TIMEOUT',
    defaultValue: 30,
  );

  // ── 便捷判断 ──────────────────────────────────────────

  static bool get talkerLogAll => talkerLogLevel == 'all';
}

/// 代理请求认证头名称（客户端与 proxy_server 共用）
const String proxyAuthHeader = 'X-S1-Proxy-Token';
