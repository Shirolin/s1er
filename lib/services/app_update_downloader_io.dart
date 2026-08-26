import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';
import '../config/env_config.dart';
import '../models/app_exceptions.dart';
import 'talker.dart';
import 'update_check_service.dart';

/// 应用内 APK 下载结果。
class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({
    required this.filePath,
    required this.sourceUrl,
  });

  final String filePath;
  final String sourceUrl;
}

/// 独立 Dio 下载 APK（不走论坛 [S1HttpClient]）。
class AppUpdateDownloader {
  AppUpdateDownloader({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
  })  : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _dio = dio ?? _createDio();

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  CancelToken? _cancelToken;

  /// GitHub 直链在部分网络下会把字节传完却不关闭连接；
  /// 浏览器表现为进度 100% 不出安装按钮，Dio 则等到 receiveTimeout 后当失败。
  static const Map<String, String> apkRequestHeaders = {
    HttpHeaders.acceptHeader: 'application/octet-stream',
    HttpHeaders.acceptEncodingHeader: 'identity',
    HttpHeaders.connectionHeader: 'close',
    HttpHeaders.userAgentHeader: S1Constants.desktopUserAgent,
  };

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(
          seconds: EnvConfig.connectTimeoutSeconds,
        ),
        sendTimeout: const Duration(
          seconds: EnvConfig.sendTimeoutSeconds,
        ),
        // APK 较大；与图床上传同量级，避免默认 30s 被砍。
        receiveTimeout: const Duration(
          seconds: EnvConfig.imageUploadTimeoutSeconds,
        ),
        followRedirects: true,
        maxRedirects: 8,
      ),
    );
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.userAgent = S1Constants.desktopUserAgent;
        client.autoUncompress = false;
        client.idleTimeout = const Duration(seconds: 5);
        return client;
      };
    }
    return dio;
  }

  /// 取消进行中的下载。
  void cancel() {
    _cancelToken?.cancel('cancelled');
    _cancelToken = null;
  }

  /// 按 [urls] 依次尝试下载；全部失败则抛 [UpdateCheckException]。
  ///
  /// [extension] 只能是 `apk` 或 `zip`（Windows 绿色包）。
  Future<AppUpdateDownloadResult> downloadApk({
    required List<String> urls,
    required String versionLabel,
    void Function(double progress)? onProgress,
    String extension = 'apk',
  }) async {
    final ext = extension.trim().toLowerCase();
    if (ext != 'apk' && ext != 'zip') {
      throw const UpdateCheckException('下载文件类型无效');
    }

    final sanitized = <String>[];
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      if (!UpdateCheckService.isAllowedDownloadUrl(url)) {
        talker.warning('Skip disallowed APK URL host: $url');
        continue;
      }
      if (!sanitized.contains(url)) sanitized.add(url);
    }
    if (sanitized.isEmpty) {
      throw const UpdateCheckException('没有可用的下载地址');
    }

    final dir = await _updatesDir();
    final safeLabel = versionLabel.replaceAll(RegExp(r'[^\w.\-+]'), '_');
    final target = File(p.join(dir.path, 's1er-$safeLabel.$ext'));
    if (await target.exists()) {
      await target.delete();
    }

    Object? lastError;
    var lastMessage = '下载失败';

    for (var i = 0; i < sanitized.length; i++) {
      final url = sanitized[i];
      final token = CancelToken();
      _cancelToken = token;
      var expectedLength = 0;
      try {
        onProgress?.call(0);
        expectedLength = await _downloadToFile(
          url: url,
          target: target,
          token: token,
          onProgress: onProgress,
        );
        _cancelToken = null;
        await _validateArchiveFile(target, expectedLength: expectedLength);
        onProgress?.call(1);
        return AppUpdateDownloadResult(
          filePath: target.path,
          sourceUrl: url,
        );
      } on DioException catch (e, st) {
        if (e.type == DioExceptionType.cancel) {
          await _deleteQuietly(target);
          talker.warning('APK download cancelled');
          throw const UpdateCheckException('已取消下载');
        }
        if (await _salvageIfComplete(target, expectedLength: expectedLength)) {
          _cancelToken = null;
          onProgress?.call(1);
          return AppUpdateDownloadResult(
            filePath: target.path,
            sourceUrl: url,
          );
        }
        lastError = e;
        lastMessage = _messageForDio(e);
        await _deleteQuietly(target);
        final isLast = i == sanitized.length - 1;
        if (isLast) {
          talker.handle(e, st, 'APK download failed');
        } else {
          talker.warning(
            'APK download failed ($url), trying next: $lastMessage',
          );
        }
      } on Object catch (e, st) {
        if (await _salvageIfComplete(target, expectedLength: expectedLength)) {
          _cancelToken = null;
          onProgress?.call(1);
          return AppUpdateDownloadResult(
            filePath: target.path,
            sourceUrl: url,
          );
        }
        lastError = e;
        lastMessage = e is UpdateCheckException ? e.message : '下载失败';
        await _deleteQuietly(target);
        final isLast = i == sanitized.length - 1;
        if (isLast) {
          talker.handle(e, st, 'APK download failed');
        } else {
          talker.warning(
            'APK download failed ($url), trying next: $lastMessage',
          );
        }
      }
    }

    _cancelToken = null;
    throw UpdateCheckException(lastMessage, lastError);
  }

  /// 把响应流写入 [target]；字节数达到 Content-Length 即结束，不等连接关闭。
  ///
  /// 返回声明的 Content-Length（未知则为 0）。
  Future<int> _downloadToFile({
    required String url,
    required File target,
    required CancelToken token,
    void Function(double progress)? onProgress,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 8,
        headers: apkRequestHeaders,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    final body = response.data;
    if (body == null) {
      throw const UpdateCheckException('下载响应无效');
    }

    final expected = _contentLengthOf(response.headers) ??
        _contentLengthFromMap(body.headers) ??
        0;

    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in body.stream) {
        if (token.isCancelled) {
          throw DioException(
            requestOptions: response.requestOptions,
            type: DioExceptionType.cancel,
          );
        }
        sink.add(chunk);
        received += chunk.length;
        if (expected > 0) {
          onProgress?.call((received / expected).clamp(0.0, 1.0));
          if (received >= expected) break;
        }
      }
    } finally {
      await sink.close();
    }

    if (expected > 0 && received < expected) {
      throw const UpdateCheckException('下载不完整');
    }
    if (received <= 0) {
      throw const UpdateCheckException('下载文件为空');
    }
    return expected;
  }

  Future<Directory> _updatesDir() async {
    final root = await _temporaryDirectory();
    final dir = Directory(p.join(root.path, 'updates'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> _salvageIfComplete(
    File file, {
    required int expectedLength,
  }) async {
    try {
      await _validateArchiveFile(file, expectedLength: expectedLength);
      talker.warning(
        'Update download stream stalled after complete file; installing anyway',
      );
      return true;
    } on Object {
      return false;
    }
  }

  static Future<void> _validateArchiveFile(
    File file, {
    int expectedLength = 0,
  }) async {
    final lower = file.path.toLowerCase();
    if (!lower.endsWith('.apk') && !lower.endsWith('.zip')) {
      await _deleteQuietly(file);
      throw const UpdateCheckException('下载文件无效');
    }
    if (!await file.exists()) {
      throw const UpdateCheckException('下载文件不存在');
    }
    final length = await file.length();
    if (length <= 0) {
      await _deleteQuietly(file);
      throw const UpdateCheckException('下载文件为空');
    }
    if (expectedLength > 0 && length < expectedLength) {
      await _deleteQuietly(file);
      throw const UpdateCheckException('下载不完整');
    }
    if (!await _hasZipMagic(file)) {
      await _deleteQuietly(file);
      throw const UpdateCheckException('下载文件无效');
    }
  }

  /// ZIP/APK 本地文件头：`PK\x03\x04`（空包 `PK\x05\x06`）。
  static Future<bool> _hasZipMagic(File file) async {
    final raf = await file.open();
    try {
      final magic = await raf.read(4);
      if (magic.length < 4) return false;
      return magic[0] == 0x50 &&
          magic[1] == 0x4B &&
          (magic[2] == 0x03 || magic[2] == 0x05 || magic[2] == 0x07);
    } finally {
      await raf.close();
    }
  }

  static int? _contentLengthOf(Headers headers) {
    final raw = headers.value(Headers.contentLengthHeader);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static int? _contentLengthFromMap(Map<String, List<String>> headers) {
    List<String>? values;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == Headers.contentLengthHeader) {
        values = entry.value;
        break;
      }
    }
    if (values == null || values.isEmpty) return null;
    return int.tryParse(values.first);
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // best-effort cleanup
    }
  }

  static String _messageForDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '下载超时',
      DioExceptionType.connectionError => '网络不可用，下载失败',
      DioExceptionType.cancel => '已取消下载',
      DioExceptionType.badResponse => _messageForStatus(e.response?.statusCode),
      _ => '下载失败',
    };
  }

  static String _messageForStatus(int? statusCode) {
    return switch (statusCode) {
      404 => '安装包不存在',
      401 || 403 => '无权下载安装包',
      final code when code != null && code >= 500 => '下载服务暂时不可用',
      final code when code != null => '下载失败（HTTP $code）',
      _ => '下载失败',
    };
  }
}
