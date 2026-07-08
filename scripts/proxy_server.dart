import 'dart:io';
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

void main() async {
  final server = await HttpServer.bind('localhost', ResourceDomains.proxyPort);
  print('Proxy on http://localhost:${ResourceDomains.proxyPort}');

  await for (final req in server) {
    try {
      final res = req.response;

      if (req.method == 'OPTIONS') {
        _cors(req, res);
        res.statusCode = 204;
        await res.close();
        continue;
      }

      final isImgProxy = req.uri.path.startsWith('/img-proxy');

      // 确定目标 URL
      Uri target;
      if (isImgProxy) {
        final targetUrl = req.uri.queryParameters['url'];
        if (targetUrl == null) {
          res.statusCode = 400;
          await res.close();
          continue;
        }
        // 404 缓存命中：直接返回，不请求上游
        if (_imgProxy404Cache.contains(targetUrl)) {
          _cors(req, res);
          res.statusCode = 404;
          await res.close();
          continue;
        }
        target = Uri.parse(targetUrl);
      } else {
        var path = req.uri.path;
        final query = req.uri.query;
        if (!path.startsWith('/2b/')) path = '/2b$path';
        target = Uri.parse('https://${ResourceDomains.apiHost}$path${query.isNotEmpty ? '?$query' : ''}');
      }

      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      final upReq = await client.openUrl(req.method, target);

      if (isImgProxy) {
        // 认证图片：根据 resource_domains 配置决定请求头
        upReq.headers.set('Host', target.host);
        upReq.headers.set('Referer', ResourceDomains.getReferer(target.host));
        upReq.headers.set('User-Agent', mobileUserAgent);
        upReq.headers.set('Accept', 'image/*,*/*;q=0.8');
        _attachCookies(upReq);
      } else {
        // API：转发原始请求头 + Cookie
        final ct = req.headers.contentType;
        if (ct != null) upReq.headers.set('Content-Type', ct.toString());
        upReq.headers.set('User-Agent', mobileUserAgent);
        _attachCookies(upReq);
      }

      final body = await req.fold<List<int>>([], (a, b) => a..addAll(b));
      if (body.isNotEmpty) {
        upReq.bufferOutput = true;
        upReq.headers.set('Content-Length', body.length.toString());
        upReq.add(body);
      }

      print('>>> ${req.method} $target');
      final upRes = await upReq.close();
      print('<<< ${upRes.statusCode}');

      // 存储上游响应的 Cookie
      _storeCookies(upRes.headers['set-cookie']);

      final bytes = await upRes.fold<List<int>>([], (a, b) => a..addAll(b));
      client.close(force: true);

      // img-proxy 404 写入缓存
      if (isImgProxy && upRes.statusCode == 404) {
        _imgProxy404Cache.add(req.uri.queryParameters['url']!);
        print('  404 cached: ${req.uri.queryParameters['url']}');
      }

      res.statusCode = upRes.statusCode;
      _cors(req, res);

      // 转发 set-cookie 给浏览器
      _forwardCookies(res, upRes.headers['set-cookie']);

      res.add(bytes);
      await res.close();
    } catch (e, st) {
      print('ERROR: $e\n$st');
      try {
        req.response.statusCode = 502;
        req.response.write('Proxy error: $e');
        await req.response.close();
      } catch (_) {}
    }
  }
}

/// 从 Cookie 罐中加载匹配的 Cookie 并附加到请求
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

/// 从响应的 Set-Cookie 头解析并存储到 Cookie 罐
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

/// 转发 set-cookie 给浏览器（清理 domain/secure 限制）
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

void _cors(HttpRequest req, HttpResponse res) {
  final origin = req.headers.value('Origin') ?? 'http://localhost:${ResourceDomains.proxyPort}';
  res.headers.set('Access-Control-Allow-Origin', origin);
  res.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.headers.set('Access-Control-Allow-Headers', 'Content-Type, Cookie');
  res.headers.set('Access-Control-Allow-Credentials', 'true');
}
