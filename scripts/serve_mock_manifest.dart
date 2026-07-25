import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 本地 mock 升级清单（带 CORS），供 Web / 原生预览更新弹窗。
///
/// ```bash
/// # 终端 1
/// dart run scripts/serve_mock_manifest.dart
///
/// # 终端 2 — Web / 桌面（本机）
/// flutter run -d chrome \
///   --dart-define=UPDATE_MANIFEST_URL=http://127.0.0.1:8765/mock-latest.json
///
/// # Android 模拟器访问宿主机
/// flutter run \
///   --dart-define=UPDATE_MANIFEST_URL=http://10.0.2.2:8765/mock-latest.json
/// ```
///
/// 冷启动约 3 秒后应自动弹出升级 Dialog；设置 → 检查更新 亦可触发。
/// 默认读取 [defaultManifestPath]；可用 `--file` 覆盖。
const defaultPort = 8765;
const defaultManifestPath = 'docs/release/mock-latest.json';
const servePath = '/mock-latest.json';

final _allowedOrigin = RegExp(
  r'^http://(localhost|127\.0\.0\.1)(:\d+)?$',
);

void main(List<String> args) async {
  final options = _parseArgs(args);
  final file = File(options.manifestPath);
  if (!file.existsSync()) {
    stderr.writeln('Manifest not found: ${file.path}');
    exit(1);
  }

  final payload = file.readAsStringSync();
  // 启动时校验 JSON，避免跑着跑着才发现格式错。
  jsonDecode(payload);

  late final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, options.port);
  } on SocketException catch (e) {
    if (e.osError?.errorCode == 10048 || e.osError?.errorCode == 98) {
      stderr.writeln('Port ${options.port} is already in use.');
      stderr.writeln('');
      stderr.writeln('Either stop the existing process, or use another port:');
      stderr.writeln('  dart run scripts/serve_mock_manifest.dart --port 8766');
      stderr.writeln('');
      stderr.writeln('Windows — find PID:  netstat -ano | findstr :${options.port}');
      stderr.writeln('Windows — kill:      taskkill /PID <pid> /F');
      exit(1);
    }
    rethrow;
  }
  final baseUrl = 'http://127.0.0.1:${options.port}$servePath';

  stdout.writeln('Mock update manifest on $baseUrl');
  stdout.writeln('Source: ${file.path}');
  stdout.writeln('');
  stdout.writeln('Flutter:');
  stdout.writeln(
    '  flutter run -d chrome '
    '--dart-define=UPDATE_MANIFEST_URL=$baseUrl',
  );

  await for (final req in server) {
    unawaited(_handleRequest(req, payload));
  }
}

class _Options {
  const _Options({required this.port, required this.manifestPath});

  final int port;
  final String manifestPath;
}

_Options _parseArgs(List<String> args) {
  var port = defaultPort;
  var manifestPath = defaultManifestPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--port' || arg == '-p') {
      final raw = args.elementAtOrNull(++i);
      if (raw == null) {
        throw ArgumentError('Missing value for $arg');
      }
      port = int.parse(raw);
      continue;
    }
    if (arg == '--file' || arg == '-f') {
      final raw = args.elementAtOrNull(++i);
      if (raw == null) {
        throw ArgumentError('Missing value for $arg');
      }
      manifestPath = raw;
      continue;
    }
    if (arg == '--help' || arg == '-h') {
      stdout.writeln('Usage: dart run scripts/serve_mock_manifest.dart '
          '[--port $defaultPort] [--file $defaultManifestPath]');
      exit(0);
    }
    throw ArgumentError('Unknown argument: $arg');
  }

  return _Options(port: port, manifestPath: manifestPath);
}

Future<void> _handleRequest(HttpRequest req, String payload) async {
  final res = req.response;
  try {
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

    if (req.method != 'GET') {
      _applyCors(req, res);
      res.statusCode = 405;
      res.write('Method not allowed');
      await res.close();
      return;
    }

    if (req.uri.path != servePath) {
      _applyCors(req, res);
      res.statusCode = 404;
      res.write('Not found. Use $servePath');
      await res.close();
      return;
    }

    if (!_applyCors(req, res)) {
      res.statusCode = 403;
      await res.close();
      return;
    }

    res.headers.contentType = ContentType.json;
    res.headers.add('Cache-Control', 'no-store');
    res.write(payload);
    await res.close();
  } on Object catch (e, st) {
    stderr.writeln('Request error: $e\n$st');
    try {
      res.statusCode = 500;
      await res.close();
    } on Object {
      // response 可能已关闭
    }
  }
}

bool _applyCors(HttpRequest req, HttpResponse res) {
  final origin = req.headers.value('Origin');
  if (origin == null || origin.isEmpty) {
    // curl / Dio 等非浏览器客户端
    return true;
  }
  if (!_allowedOrigin.hasMatch(origin)) {
    return false;
  }
  res.headers.set('Access-Control-Allow-Origin', origin);
  res.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.headers.set('Access-Control-Allow-Headers', 'Content-Type, Accept');
  res.headers.set('Vary', 'Origin');
  return true;
}
