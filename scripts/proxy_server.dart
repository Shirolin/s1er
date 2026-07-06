// 本地 CORS 代理服务器
// 用法: dart run scripts/proxy_server.dart
// 会在 http://localhost:8080 启动代理

import 'dart:io';
import 'dart:convert';

void main() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('CORS Proxy running on http://localhost:8080');
  print('将请求转发到 https://stage1st.com/2b');

  await for (final request in server) {
    // 添加 CORS 头
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');
    request.response.headers.add('Access-Control-Allow-Credentials', 'true');

    // 处理 OPTIONS 预检请求
    if (request.method == 'OPTIONS') {
      await request.response.close();
      continue;
    }

    // 构建目标 URL（包含查询参数）
    var targetPath = request.uri.path;
    if (!targetPath.startsWith('/')) {
      targetPath = '/$targetPath';
    }
    
    // 如果路径不包含 /2b/ 前缀，加上
    if (!targetPath.startsWith('/2b/')) {
      targetPath = '/2b$targetPath';
    }
    
    final targetUrl = 'https://stage1st.com$targetPath';
    final uri = Uri.parse(targetUrl).replace(queryParameters: request.uri.queryParameters);

    try {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      
      HttpClientRequest proxyRequest;
      
      if (request.method == 'POST') {
        // 处理 POST 请求
        proxyRequest = await client.postUrl(uri);
        
        // 读取原始请求体
        final body = await request.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        
        // 复制 Content-Type 头
        final contentType = request.headers.contentType;
        if (contentType != null) {
          proxyRequest.headers.set('Content-Type', contentType.toString());
        }
        
        // 写入请求体
        proxyRequest.add(body);
      } else {
        // 处理其他请求方法
        proxyRequest = await client.openUrl(request.method, uri);
        
        // 读取请求体（如果有）
        final body = await request.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        if (body.isNotEmpty) {
          proxyRequest.add(body);
        }
      }

      // 复制原始请求头（排除一些不应转发的头）
      final excludeHeaders = {'host', 'origin', 'referer', 'cookie'};
      request.headers.forEach((name, values) {
        if (!excludeHeaders.contains(name.toLowerCase())) {
          proxyRequest.headers.set(name, values);
        }
      });

      // 设置 Origin 头
      proxyRequest.headers.set('Origin', 'https://stage1st.com');
      proxyRequest.headers.set('Referer', 'https://stage1st.com/2b/');

      final proxyResponse = await proxyRequest.close();

      // 复制响应头和状态码
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        if (!['transfer-encoding', 'content-encoding'].contains(name.toLowerCase())) {
          request.response.headers.set(name, values);
        }
      });

      // 转发响应体
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
