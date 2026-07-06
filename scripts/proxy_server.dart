// 本地 CORS 代理服务器
// 用法: dart run scripts/proxy_server.dart
// 会在 http://localhost:8080 启动代理

import 'dart:io';

void main() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('CORS Proxy running on http://localhost:8080');
  print('将请求转发到 https://stage1st.com/2b');

  await for (final request in server) {
    // 添加 CORS 头
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    // 处理 OPTIONS 预检请求
    if (request.method == 'OPTIONS') {
      await request.response.close();
      continue;
    }

    // 转发请求到目标服务器
    final targetUrl = 'https://stage1st.com/2b${request.uri.path}';
    final queryParams = request.uri.queryParameters;

    try {
      final client = HttpClient();
      final uri = Uri.parse(targetUrl).replace(queryParameters: queryParams);
      final proxyRequest = await client.getUrl(uri);

      // 复制原始请求头
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host') {
          proxyRequest.headers.set(name, values);
        }
      });

      final proxyResponse = await proxyRequest.close();

      // 复制响应头和状态码
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        if (name.toLowerCase() != 'transfer-encoding') {
          request.response.headers.set(name, values);
        }
      });

      await proxyResponse.pipe(request.response);
      client.close();
    } catch (e) {
      print('Proxy error: $e');
      request.response.statusCode = 502;
      await request.response.write('Proxy error: $e');
      await request.response.close();
    }
  }
}
