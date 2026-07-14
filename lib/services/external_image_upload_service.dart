import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import '../config/resource_domains.dart';
import 'talker.dart';

/// 外链图床上传（对齐 S1-Next：`p.sda1.dev`，结果以 `[img]url[/img]` 写入正文）。
///
/// Web 端经本地 CORS 代理 `/ext-upload` 转发；Native 直连图床。
class ExternalImageUploadService {
  ExternalImageUploadService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(
                  seconds: EnvConfig.connectTimeoutSeconds,
                ),
                sendTimeout: const Duration(
                  seconds: EnvConfig.imageUploadTimeoutSeconds,
                ),
                receiveTimeout: const Duration(
                  seconds: EnvConfig.imageUploadTimeoutSeconds,
                ),
                responseType: ResponseType.plain,
              ),
            );

  final Dio _dio;

  /// 流浪图床单文件上限（官网文案 5 MB）。
  static const int maxBytes = 5 * 1024 * 1024;

  /// 解析实际上传 URL（Web → 本地代理）。
  static String resolveUploadUrl({
    required String filename,
    bool isWeb = kIsWeb,
  }) {
    final safeName = filename.trim().isEmpty ? 'image.jpg' : filename.trim();
    final query = 'filename=${Uri.encodeQueryComponent(safeName)}';
    if (isWeb) {
      return 'http://localhost:${EnvConfig.proxyPort}/ext-upload?$query';
    }
    return '${ResourceDomains.externalImageUploadUrl}?$query';
  }

  /// 上传原始字节，返回公网图片 URL。
  Future<String> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    final safeName = filename.trim().isEmpty ? 'image.jpg' : filename.trim();
    if (bytes.isEmpty) {
      throw const ExternalImageUploadException('图片内容为空');
    }
    if (bytes.length > maxBytes) {
      throw ExternalImageUploadException(
        '图片过大（${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB），'
        '图床上限 ${maxBytes ~/ (1024 * 1024)} MB，请压缩后再试',
      );
    }

    final url = resolveUploadUrl(filename: safeName);

    try {
      final headers = <String, dynamic>{};
      // 浏览器禁止设置 Content-Length；强写会搞乱 Web 请求/CORS 预检。
      if (!kIsWeb) {
        headers[Headers.contentLengthHeader] = bytes.length;
      }
      if (kIsWeb && EnvConfig.proxyAuthToken.isNotEmpty) {
        headers[proxyAuthHeader] = EnvConfig.proxyAuthToken;
      }

      final response = await _dio.post<String>(
        url,
        data: bytes,
        options: Options(
          contentType: _contentTypeFor(safeName),
          headers: headers,
          sendTimeout: const Duration(
            seconds: EnvConfig.imageUploadTimeoutSeconds,
          ),
          receiveTimeout: const Duration(
            seconds: EnvConfig.imageUploadTimeoutSeconds,
          ),
        ),
      );

      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const ExternalImageUploadException('图床返回空响应');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const ExternalImageUploadException('图床响应格式错误');
      }
      if (decoded['code']?.toString() != 'success') {
        throw ExternalImageUploadException(
          '图床上传失败（${decoded['code'] ?? 'unknown'}）',
        );
      }
      final data = decoded['data'];
      final imageUrl = data is Map ? data['url']?.toString() : null;
      if (imageUrl == null || imageUrl.isEmpty) {
        throw const ExternalImageUploadException('图床未返回图片地址');
      }
      return imageUrl;
    } on ExternalImageUploadException {
      rethrow;
    } on DioException catch (e, st) {
      talker.handle(e, st, 'External image upload failed');
      throw ExternalImageUploadException(_messageForDio(e));
    } catch (e, st) {
      talker.handle(e, st, 'External image upload failed');
      throw const ExternalImageUploadException('图片上传失败，请稍后重试');
    }
  }

  static String _messageForDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '图片上传超时，请换较小文件或稍后重试';
      case DioExceptionType.connectionError:
        return '无法连接图床，请检查网络或本时代理是否已启动';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 504 || code == 502) {
          return '图床代理超时，请稍后重试';
        }
        return '图片上传失败（HTTP ${code ?? 'error'}）';
      case DioExceptionType.cancel:
        return '图片上传已取消';
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return '图片上传失败，请稍后重试';
    }
  }

  static String _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }
}

class ExternalImageUploadException implements Exception {
  const ExternalImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
