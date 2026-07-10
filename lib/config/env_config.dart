class EnvConfig {
  EnvConfig._();

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
}

/// 代理请求认证头名称（客户端与 proxy_server 共用）
const String proxyAuthHeader = 'X-S1-Proxy-Token';
