import 'dart:io';

const int port = 19080;
const String targetHost = 'https://stage1st.com';
const String mobileUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/17.0 Mobile/15E148 Safari/604.1';

void main() async {
  final server = await HttpServer.bind('localhost', port);
  print('Proxy on http://localhost:$port');

  await for (final req in server) {
    try {
      final res = req.response;

      if (req.method == 'OPTIONS') {
        _cors(req, res);
        res.statusCode = 204;
        await res.close();
        continue;
      }

      var path = req.uri.path;
      if (!path.startsWith('/2b/')) path = '/2b$path';
      final qs = req.uri.query;
      final target = Uri.parse('$targetHost$path${qs.isNotEmpty ? '?$qs' : ''}');

      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      final upReq = await client.openUrl(req.method, target);

      final ct = req.headers.contentType;
      if (ct != null) upReq.headers.set('Content-Type', ct.toString());
      final ck = req.headers.value('Cookie');
      if (ck != null && ck.isNotEmpty) {
        final filteredCookies = <String>[];
        final parts = ck.split(';');
        for (var part in parts) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) continue;
          final eqIdx = trimmed.indexOf('=');
          if (eqIdx == -1) continue;
          final name = trimmed.substring(0, eqIdx);
          
          // 只允许以 S1 官方 Cookie 前缀 'B7Y9_2f85_' 开头的 Cookie 被转发
          // 这会彻底清洗掉 localhost 下由其他开发项目写入的全部无关/非规范 Cookie，一劳永逸解决 XSS 拦截问题
          if (name.startsWith('B7Y9_2f85_')) {
            filteredCookies.add(trimmed);
          }
        }
        if (filteredCookies.isNotEmpty) {
          upReq.headers.set('Cookie', filteredCookies.join('; '));
        }
      }
      upReq.headers.set('User-Agent', mobileUserAgent);

      final body = await req.fold<List<int>>([], (a, b) => a..addAll(b));
      if (body.isNotEmpty) {
        upReq.bufferOutput = true;
        upReq.headers.set('Content-Length', body.length.toString());
        upReq.add(body);
      }
      print('>>> ${req.method} $target');
      print('>>> Content-Type: ${ct ?? "null"}');
      print('>>> Body: ${String.fromCharCodes(body)}');
      final upRes = await upReq.close();
      print('<<< ${upRes.statusCode}');

      final bytes = await upRes.fold<List<int>>([], (a, b) => a..addAll(b));
      client.close(force: true);

      res.statusCode = upRes.statusCode;
      _cors(req, res);

      final sc = upRes.headers['set-cookie'];
      if (sc != null) {
        for (final v in sc) {
          // 清理 set-cookie 响应头，剥离 domain 限制和 secure 传输要求，
          // 让本地 localhost HTTP 调试环境的浏览器可以正常写入并携带这些 Cookie
          final parts = v.split(';');
          final cleanedParts = parts.where((part) {
            final trimmed = part.trim().toLowerCase();
            return !trimmed.startsWith('domain=') && trimmed != 'secure';
          }).toList();
          res.headers.add('set-cookie', cleanedParts.join('; '));
        }
      }

      res.add(bytes);
      await res.close();
    } catch (e, st) {
      print('ERROR: $e');
      print('STACK: $st');
      try {
        req.response.statusCode = 502;
        req.response.write('Proxy error: $e');
        await req.response.close();
      } catch (_) {}
    }
  }
}

void _cors(HttpRequest req, HttpResponse res) {
  final origin = req.headers.value('Origin') ?? 'http://localhost:$port';
  res.headers.set('Access-Control-Allow-Origin', origin);
  res.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.headers.set('Access-Control-Allow-Headers', 'Content-Type, Cookie');
  res.headers.set('Access-Control-Allow-Credentials', 'true');
}
