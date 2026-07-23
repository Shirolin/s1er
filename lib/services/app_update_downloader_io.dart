import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
        _dio = dio ??
            Dio(
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
                responseType: ResponseType.bytes,
                followRedirects: true,
                maxRedirects: 5,
              ),
            );

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  CancelToken? _cancelToken;

  /// 取消进行中的下载。
  void cancel() {
    _cancelToken?.cancel('cancelled');
    _cancelToken = null;
  }

  /// 按 [urls] 依次尝试下载；全部失败则抛 [UpdateCheckException]。
  Future<AppUpdateDownloadResult> downloadApk({
    required List<String> urls,
    required String versionLabel,
    void Function(double progress)? onProgress,
  }) async {
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
    final target = File(p.join(dir.path, 's1er-$safeLabel.apk'));
    if (await target.exists()) {
      await target.delete();
    }

    Object? lastError;
    var lastMessage = '下载失败';

    for (var i = 0; i < sanitized.length; i++) {
      final url = sanitized[i];
      final token = CancelToken();
      _cancelToken = token;
      try {
        onProgress?.call(0);
        await _dio.download(
          url,
          target.path,
          cancelToken: token,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            onProgress?.call((received / total).clamp(0.0, 1.0));
          },
        );
        _cancelToken = null;
        await _validateApkFile(target);
        onProgress?.call(1);
        return AppUpdateDownloadResult(
          filePath: target.path,
          sourceUrl: url,
        );
      } on DioException catch (e, st) {
        lastError = e;
        lastMessage = _messageForDio(e);
        await _deleteQuietly(target);
        if (e.type == DioExceptionType.cancel) {
          talker.warning('APK download cancelled');
          throw const UpdateCheckException('已取消下载');
        }
        final isLast = i == sanitized.length - 1;
        if (isLast) {
          talker.handle(e, st, 'APK download failed');
        } else {
          talker.warning(
            'APK download failed ($url), trying next: $lastMessage',
          );
        }
      } on Object catch (e, st) {
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

  Future<Directory> _updatesDir() async {
    final root = await _temporaryDirectory();
    final dir = Directory(p.join(root.path, 'updates'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _validateApkFile(File file) async {
    if (!file.path.toLowerCase().endsWith('.apk')) {
      await _deleteQuietly(file);
      throw const UpdateCheckException('下载文件无效');
    }
    if (!await file.exists()) {
      throw const UpdateCheckException('下载文件不存在');
    }
    final length = await file.length();
    if (length < 4) {
      await _deleteQuietly(file);
      throw UpdateCheckException(
        length <= 0 ? '下载文件为空' : '下载文件不是有效安装包',
      );
    }
    final raf = await file.open();
    try {
      final header = await raf.read(4);
      // ZIP local file header (APK = ZIP)
      const zipMagic = [0x50, 0x4B, 0x03, 0x04];
      if (header.length != 4 ||
          header[0] != zipMagic[0] ||
          header[1] != zipMagic[1] ||
          header[2] != zipMagic[2] ||
          header[3] != zipMagic[3]) {
        await _deleteQuietly(file);
        throw const UpdateCheckException('下载文件不是有效安装包');
      }
    } finally {
      await raf.close();
    }
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
