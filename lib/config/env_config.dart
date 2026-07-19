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

  /// BBCode / Html 构建耗时打点（默认 false；仅调试滑动卡顿用）
  static const bool bbcodeProfile = bool.fromEnvironment(
    'BBCODE_PROFILE',
    defaultValue: false,
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

  /// 请求发送超时（秒，默认 30）
  static const int sendTimeoutSeconds = int.fromEnvironment(
    'SEND_TIMEOUT',
    defaultValue: 30,
  );

  /// 外链图床上传超时（秒，默认 120；经代理双跳 + 大图更易超过 API 默认 30s）
  static const int imageUploadTimeoutSeconds = int.fromEnvironment(
    'IMAGE_UPLOAD_TIMEOUT',
    defaultValue: 120,
  );

  /// 应用升级清单 URL（默认 GitHub raw latest.json）
  static const String updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/Shirolin/s1er/main/docs/release/latest.json',
  );

  /// 分发渠道：`github`（默认）或 `play`（上架包 CTA 优先 Play）
  static const String distribution = String.fromEnvironment(
    'DISTRIBUTION',
    defaultValue: 'github',
  );

  // ── 监控 ──────────────────────────────────────────────

  /// Sentry DSN（通过 --dart-define 注入，为空则禁用 Sentry）
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static bool get sentryEnabled => sentryDsn.isNotEmpty;

  /// Performance traces 采样率（0–1；默认 0 = 仅错误，不开性能）
  static const String _sentryTracesSampleRateRaw = String.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0',
  );

  static double get sentryTracesSampleRate {
    final parsed = double.tryParse(_sentryTracesSampleRateRaw) ?? 0;
    if (parsed < 0) return 0;
    if (parsed > 1) return 1;
    return parsed;
  }

  /// Debug 构建是否允许实际上传（默认 false，防止本机误开 DSN 刷配额）
  static const bool sentryDebugUpload = bool.fromEnvironment(
    'SENTRY_DEBUG_UPLOAD',
    defaultValue: false,
  );

  // ── 便捷判断 ──────────────────────────────────────────

  static bool get talkerLogAll => talkerLogLevel == 'all';
}

/// 代理请求认证头名称（客户端与 proxy_server 共用）
const String proxyAuthHeader = 'X-S1-Proxy-Token';
