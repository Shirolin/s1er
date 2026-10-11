import 'dart:convert';
import 'dart:io';

/// 本地升级端到端测试用的小型 HTTP 服务器（仅本机，不对外）。
///
/// 提供两份资源，供 debug 构建 + `UPDATE_ALLOW_LOCAL_HOST=true` 的客户端拉取：
///   GET /latest.json  → 指向本服务器的升级清单
///   GET /s1er.zip     → 覆盖更新用的绿色包
///
/// 用法：
///   dart run scripts/serve_update_local.dart \
///     --zip path/to/s1er.zip --version 0.9.0 [--port 8099] \
///     [--min-supported 0.0.0] [--notes "本地测试"]
void main(List<String> args) async {
  final opts = _parseArgs(args);
  final zipPath = opts['zip'];
  if (zipPath == null || zipPath.isEmpty) {
    stderr.writeln('missing --zip <path>');
    exit(2);
  }
  final zip = File(zipPath);
  if (!zip.existsSync()) {
    stderr.writeln('zip not found: $zipPath');
    exit(2);
  }
  final version = opts['version'] ?? '0.0.1';
  final port = int.tryParse(opts['port'] ?? '') ?? 8099;
  final minSupported = opts['min-supported'] ?? '0.0.0';
  final notes = opts['notes'] ?? '本地覆盖更新测试';

  final base = 'http://127.0.0.1:$port';
  final manifest = {
    'latest': version,
    'minSupported': minSupported,
    'notes': notes,
    'publishedAt': DateTime.now().toIso8601String().substring(0, 10),
    'channels': {
      'github': base,
      'windows': '$base/s1er.zip',
    },
  };
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  final zipBytes = zip.readAsBytesSync();

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('local update server: $base');
  stdout.writeln(
      '  latest.json  -> version $version (minSupported $minSupported)');
  stdout.writeln('  s1er.zip     -> $zipPath (${zipBytes.length} bytes)');
  stdout.writeln('');
  stdout.writeln('run the app with:');
  stdout.writeln(
    '  --dart-define=UPDATE_ALLOW_LOCAL_HOST=true '
    '--dart-define=UPDATE_MANIFEST_URL=$base/latest.json',
  );

  await for (final req in server) {
    final path = req.uri.path;
    stdout.writeln('${DateTime.now().toIso8601String()}  ${req.method} $path');
    if (path == '/latest.json') {
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..headers.set('Cache-Control', 'no-store')
        ..add(manifestBytes);
    } else if (path == '/s1er.zip') {
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType('application', 'zip')
        ..headers.contentLength = zipBytes.length
        ..add(zipBytes);
    } else {
      req.response.statusCode = 404;
    }
    await req.response.close();
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final name = a.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[name] = args[++i];
    } else {
      out[name] = 'true';
    }
  }
  return out;
}
