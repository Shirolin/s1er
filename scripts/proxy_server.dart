// 本地 CORS 代理服务器
// 用法: dart run scripts/proxy_server.dart
// 会在 http://localhost:19080 启动代理

import 'dart:io';

const int port = 19080;
const String targetHost = 'https://stage1st.com';
const String mobileUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/17.0 Mobile/15E148 Safari/604.1';

void main() async {
  final server = await HttpServer.bind('localhost', port);
  print('CORS Proxy running on http://localhost:$port');
  print('转发到 $targetHost/2b');

  await for (final request in server) {
    // CORS 响应头
    request.response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
      ..add('Access-Control-Allow-Headers', 'Content-Type, Cookie')
      ..add('Access-Control-Allow-Credentials', 'true');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      continue;
    }

    // 构建目标路径
    var targetPath = request.uri.path;
    if (!targetPath.startsWith('/2b/')) {
      targetPath = '/2b$targetPath';
    }

    final uri = Uri.parse('$targetHost$targetPath')
        .replace(queryParameters: request.uri.queryParameters);

    try {
      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;

      final proxyRequest = await client.openUrl(request.method, uri);

      // 读取请求体
      final body = await request.fold<List<int>>([], (p, c) => p..addAll(c));
      if (body.isNotEmpty) {
        proxyRequest.add(body);
      }

      // 转发 Content-Type
      final ct = request.headers.contentType;
      if (ct != null) {
        proxyRequest.headers.set('Content-Type', ct.toString());
      }

      // 转发 Cookie
      final cookieHeader = request.headers.value('Cookie');
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        proxyRequest.headers.set('Cookie', cookieHeader);
      }

      // 代理设置安全头
      proxyRequest.headers
        ..set('User-Agent', mobileUserAgent)
        ..set('Origin', targetHost)
        ..set('Referer', '$targetHost/2b/');

      final proxyResponse = await proxyRequest.close();

      // 写回响应
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        if (!['transfer-encoding', 'content-encoding'].contains(name.toLowerCase())) {
          request.response.headers.set(name, values);
        }
      });

      // 手动复制响应体
      await for (final chunk in proxyResponse) {
        request.response.add(chunk);
      }
      await request.response.close();
      client.close();
    } catch (e) {
      print('Proxy error: $e');
      request.response.statusCode = 502;
      request.response.write('Proxy error: $e');
      await request.response.close();
    }
  }
}
