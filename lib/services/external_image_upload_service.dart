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
                  seconds: EnvConfig.sendTimeoutSeconds,
                ),
                receiveTimeout: const Duration(
                  seconds: EnvConfig.receiveTimeoutSeconds,
                ),
                responseType: ResponseType.plain,
              ),
            );

  final Dio _dio;

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
    final url = resolveUploadUrl(filename: safeName);

    try {
      final headers = <String, dynamic>{
        Headers.contentLengthHeader: bytes.length,
      };
      if (kIsWeb && EnvConfig.proxyAuthToken.isNotEmpty) {
        headers[proxyAuthHeader] = EnvConfig.proxyAuthToken;
      }

      final response = await _dio.post<String>(
        url,
        data: bytes,
        options: Options(
          contentType: _contentTypeFor(safeName),
          headers: headers,
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
    } catch (e, st) {
      talker.handle(e, st, 'External image upload failed');
      throw const ExternalImageUploadException('图片上传失败，请稍后重试');
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
