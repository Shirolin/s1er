import '../config/env_config.dart';
import '../config/resource_domains.dart';

/// Web 端跨域图片加载统一改写为本地 CORS 代理。
String webProxiedImageUrl(String originalUrl) {
  return 'http://localhost:${ResourceDomains.proxyPort}'
      '/img-proxy?url=${Uri.encodeComponent(originalUrl)}';
}

/// Native 原样返回；Web 走 `/img-proxy`。
String platformImageUrl(String originalUrl, {required bool isWeb}) {
  if (!isWeb) return originalUrl;
  if (originalUrl.startsWith('http://localhost:${EnvConfig.proxyPort}/')) {
    return originalUrl;
  }
  return webProxiedImageUrl(originalUrl);
}
