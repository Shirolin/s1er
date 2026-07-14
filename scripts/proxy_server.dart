import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/config/api_config.dart';
import '../lib/config/env_config.dart';
import '../lib/config/resource_domains.dart';

const String mobileUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/17.0 Mobile/15E148 Safari/604.1';

/// 代理服务器端 Cookie 罐
/// 登录时自动存储 S1 Cookie，图片请求时自动附加
final Map<String, String> _cookieJar = {};

/// img-proxy 404 缓存（避免对无头像用户重复请求）
final Set<String> _imgProxy404Cache = {};

/// 允许的 CORS Origin（仅 localhost）
final _localhostOrigin = RegExp(r'^http://localhost(:\d+)?$');

late final String _proxyAuthToken;

void main() async {
  _proxyAuthToken = _resolveAuthToken();
  final port = ResourceDomains.proxyPort;
  final server = await HttpServer.bind('localhost', port);
  print('Proxy on http://localhost:$port');
  if (EnvConfig.proxyAuthToken.isEmpty) {
    print('Auth token: DISABLED (dev mode, set PROXY_AUTH_TOKEN to enable)');
  } else {
    print('Auth token: ENABLED');
  }

  await for (final req in server) {
    unawaited(_handleRequestSafely(req));
  }
}

Future<void> _handleRequestSafely(HttpRequest req) async {
  try {
    await _handleRequest(req);
  } catch (e, st) {
    print('ERROR: $e\n$st');
    try {
      _applyCors(req, req.response);
      req.response.statusCode = e is TimeoutException ? 504 : 502;
      req.response.write('Proxy error: $e');
      await req.response.close();
    } catch (_) {}
  }
}

String _resolveAuthToken() {
  if (EnvConfig.proxyAuthToken.isNotEmpty) {
    return EnvConfig.proxyAuthToken;
  }
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

Future<void> _handleRequest(HttpRequest req) async {
  final res = req.response;

  if (req.method == 'OPTIONS') {
    if (!_applyCors(req, res)) {
      res.statusCode = 403;
      await res.close();
      return;
    }
    res.statusCode = 204;
    await res.close();
    return;
  }

  if (!_verifyAuthToken(req)) {
    _applyCors(req, res);
    res.statusCode = 403;
    res.write('Invalid proxy token');
    await res.close();
    return;
  }

  // 注销：清除代理端会话
  if (req.method == 'POST' && req.uri.path == '/proxy/session/clear') {
    _cookieJar.clear();
    _imgProxy404Cache.clear();
    if (!_applyCors(req, res)) {
      res.statusCode = 403;
      await res.close();
      return;
    }
    res.statusCode = 204;
    await res.close();
    print('Session cleared');
    return;
  }

  final isImgProxy = req.uri.path.startsWith('/img-proxy');
  // Web 端外链图床上传（浏览器无法直连 p.sda1.dev，CORS）
  final isExtUpload = req.uri.path == '/ext-upload';

  Uri target;
  ResourceType? imgResourceType;
  if (isExtUpload) {
    if (req.method != 'POST') {
      _applyCors(req, res);
      res.statusCode = 405;
      res.write('Method not allowed');
      await res.close();
      return;
    }
    final filename = req.uri.queryParameters['filename'] ?? 'image.jpg';
    target = Uri.parse(
      '${ResourceDomains.externalImageUploadUrl}'
      '?filename=${Uri.encodeQueryComponent(filename)}',
    );
  } else if (isImgProxy) {
    final targetUrl = req.uri.queryParameters['url'];
    if (targetUrl == null) {
      _applyCors(req, res);
      res.statusCode = 400;
      await res.close();
      return;
    }
    if (_imgProxy404Cache.contains(targetUrl)) {
      _applyCors(req, res);
      res.statusCode = 404;
      await res.close();
      return;
    }
    target = Uri.parse(targetUrl);
    if (!ResourceDomains.isAllowedImgProxyTarget(target)) {
      _applyCors(req, res);
      res.statusCode = 403;
      res.write('Target URL not allowed');
      await res.close();
      return;
    }
    imgResourceType = ResourceDomains.match(target.host)?.type;
  } else {
    var path = req.uri.path;
    final query = req.uri.query;
    if (!path.startsWith('/2b/')) path = '/2b$path';
    target = Uri.parse(
      'https://${ResourceDomains.apiHost}$path${query.isNotEmpty ? '?$query' : ''}',
    );
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(
      seconds: EnvConfig.connectTimeoutSeconds,
    )
    ..findProxy = _findProxy;
  final upReq = await client.openUrl(req.method, target);

  if (isImgProxy) {
    upReq.headers.set('Host', target.host);
    upReq.headers.set('Referer', ResourceDomains.getReferer(target.host));
    upReq.headers.set('User-Agent', mobileUserAgent);
    upReq.headers.set('Accept', 'image/*,*/*;q=0.8');
    if (imgResourceType == ResourceType.authImage) {
      _attachCookies(upReq);
    }
  } else if (isExtUpload) {
    final ct = req.headers.contentType;
    if (ct != null) upReq.headers.set('Content-Type', ct.toString());
    upReq.headers.set('Host', target.host);
    upReq.headers.set('User-Agent', mobileUserAgent);
    upReq.headers.set('Accept', 'application/json,*/*;q=0.8');
  } else {
    final ct = req.headers.contentType;
    if (ct != null) upReq.headers.set('Content-Type', ct.toString());
    upReq.headers.set('User-Agent', mobileUserAgent);
    upReq.headers.set('Referer', _resolveReferer(target));
    if (target.path.contains('forum.php') &&
        target.queryParameters['inajax'] == '1') {
      upReq.headers.set('X-Requested-With', 'XMLHttpRequest');
    }
    _attachCookies(upReq);
  }

  final body = await req.fold<List<int>>([], (a, b) => a..addAll(b));
  if (body.isNotEmpty) {
    upReq.bufferOutput = true;
    upReq.headers.set('Content-Length', body.length.toString());
    upReq.add(body);
  }

  // 图床上传需更长超时：Web 先收齐字节再转发，大图 + Cloudflare 易超过 API 默认 30s。
  final upstreamTimeoutSeconds = isExtUpload
      ? EnvConfig.imageUploadTimeoutSeconds
      : EnvConfig.receiveTimeoutSeconds;

  print('>>> ${req.method} $target');
  final upRes = await upReq.close().timeout(
    Duration(seconds: upstreamTimeoutSeconds),
    onTimeout: () {
      client.close(force: true);
      throw TimeoutException('Upstream response timed out: $target');
    },
  );
  print('<<< ${upRes.statusCode}');

  _storeCookies(upRes.headers['set-cookie']);

  final bytes = await upRes.fold<List<int>>([], (a, b) => a..addAll(b)).timeout(
    Duration(seconds: upstreamTimeoutSeconds),
    onTimeout: () {
      client.close(force: true);
      throw TimeoutException('Upstream body timed out: $target');
    },
  );
  client.close(force: true);

  if (isImgProxy && upRes.statusCode == 404) {
    _imgProxy404Cache.add(req.uri.queryParameters['url']!);
    print('  404 cached: ${req.uri.queryParameters['url']}');
  }

  res.statusCode = upRes.statusCode;
  _applyCors(req, res);
  _forwardCookies(res, upRes.headers['set-cookie']);

  res.add(bytes);
  await res.close();
}

String _findProxy(Uri uri) {
  final proxy = Platform.environment['S1_UPSTREAM_PROXY'] ??
      Platform.environment['HTTPS_PROXY'] ??
      Platform.environment['https_proxy'] ??
      Platform.environment['HTTP_PROXY'] ??
      Platform.environment['http_proxy'] ??
      Platform.environment['ALL_PROXY'] ??
      Platform.environment['all_proxy'];
  if (proxy == null || proxy.isEmpty) return 'DIRECT';

  final parsed = Uri.tryParse(proxy);
  if (parsed == null || parsed.host.isEmpty) return 'DIRECT';
  final port = parsed.hasPort ? parsed.port : 7890;
  return 'PROXY ${parsed.host}:$port';
}

String _resolveReferer(Uri target) {
  if (target.path.contains('forum.php')) {
    final mod = target.queryParameters['mod'];
    final action = target.queryParameters['action'];
    if (mod == 'post' && action == 'reply') {
      final fid = target.queryParameters['fid'] ?? '';
      final tid = target.queryParameters['tid'] ?? '';
      final reppost = target.queryParameters['reppost'] ?? '0';
      if (fid.isNotEmpty && tid.isNotEmpty) {
        return ApiConfig.forumReplyReferer(
          fid: fid,
          tid: tid,
          reppost: reppost,
        );
      }
    }
  }
  return ResourceDomains.defaultReferer;
}

bool _verifyAuthToken(HttpRequest req) {
  // 未显式配置 token 时跳过验证（开发模式）
  if (EnvConfig.proxyAuthToken.isEmpty) return true;
  final token = req.headers.value(proxyAuthHeader);
  return token != null && token == _proxyAuthToken;
}

bool _applyCors(HttpRequest req, HttpResponse res) {
  final origin = req.headers.value('Origin');
  if (origin != null && _localhostOrigin.hasMatch(origin)) {
    res.headers.set('Access-Control-Allow-Origin', origin);
    res.headers
        .set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Content-Length, Cookie, X-Requested-With, $proxyAuthHeader',
    );
    res.headers.set('Access-Control-Allow-Credentials', 'true');
    return true;
  }
  if (origin == null) {
    // 非浏览器直连（如 curl）无需 CORS
    return true;
  }
  return false;
}

void _attachCookies(HttpClientRequest req) {
  final matched = <String>[];
  for (final entry in _cookieJar.entries) {
    if (entry.key.startsWith(ResourceDomains.cookiePrefix)) {
      matched.add('${entry.key}=${entry.value}');
    }
  }
  if (matched.isNotEmpty) {
    req.headers.set('Cookie', matched.join('; '));
    print('  Cookies attached: ${matched.length}');
  }
}

void _storeCookies(List<String>? setCookieHeaders) {
  if (setCookieHeaders == null) return;
  for (final header in setCookieHeaders) {
    final parts = header.split(';');
    if (parts.isEmpty) continue;
    final nameValue = parts[0].trim();
    final eqIdx = nameValue.indexOf('=');
    if (eqIdx == -1) continue;
    final name = nameValue.substring(0, eqIdx).trim();
    final value = nameValue.substring(eqIdx + 1).trim();
    _cookieJar[name] = value;
    print('  Cookie stored: $name');
  }
}

void _forwardCookies(HttpResponse res, List<String>? setCookieHeaders) {
  if (setCookieHeaders == null) return;
  for (final v in setCookieHeaders) {
    final parts = v.split(';');
    final cleanedParts = parts.where((part) {
      final trimmed = part.trim().toLowerCase();
      return !trimmed.startsWith('domain=') && trimmed != 'secure';
    }).toList();
    res.headers.add('set-cookie', cleanedParts.join('; '));
  }
}
