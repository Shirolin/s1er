import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import '../models/app_exceptions.dart';
import '../models/app_update_manifest.dart';
import 'talker.dart';

/// 拉取远端升级清单（独立 Dio，不走论坛 [S1HttpClient]）。
class UpdateCheckService {
  UpdateCheckService({
    Dio? dio,
    String? manifestUrl,
  })  : _manifestUrl = manifestUrl ?? EnvConfig.updateManifestUrl,
        _dio = dio ??
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
                responseType: ResponseType.json,
                headers: const {
                  Headers.acceptHeader: 'application/json',
                },
              ),
            );

  final Dio _dio;
  final String _manifestUrl;

  String get manifestUrl => _manifestUrl;

  Future<AppUpdateManifest> fetchManifest() async {
    try {
      final response = await _dio.get<dynamic>(_manifestUrl);
      return AppUpdateManifest.fromJson(_coerceManifestMap(response.data));
    } on DioException catch (e, st) {
      final message = _messageForDio(e);
      if (_isExpectedManifestMiss(e)) {
        talker.warning('Fetch update manifest skipped: $message');
      } else {
        talker.handle(e, st, 'Fetch update manifest failed');
      }
      throw UpdateCheckException(message, e);
    } on FormatException catch (e, st) {
      talker.handle(e, st, 'Parse update manifest failed');
      rethrow;
    }
  }

  /// 私有仓库 raw URL / 错链等：客户端无法公开拉取，属预期失败。
  static bool _isExpectedManifestMiss(DioException e) {
    if (e.type != DioExceptionType.badResponse) return false;
    final code = e.response?.statusCode;
    return code == 404 || code == 401 || code == 403;
  }

  /// 允许的升级下载 / 商店主机（https only）。
  static const Set<String> allowedDownloadHosts = {
    'github.com',
    'www.github.com',
    'raw.githubusercontent.com',
    'objects.githubusercontent.com',
    'play.google.com',
  };

  /// 按分发渠道与平台解析下载 / 商店 URL。
  ///
  /// 仅返回通过主机白名单的 https URL；无一可用时返回空字符串。
  static String resolveDownloadUrl(
    AppUpdateManifest manifest, {
    String distribution = EnvConfig.distribution,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    final dist = distribution.trim().toLowerCase();
    if (dist == 'play') {
      final play = _sanitizeDownloadUrl(manifest.channels.play);
      if (play != null) return play;
    }
    if (isWeb) {
      return _sanitizeDownloadUrl(manifest.channels.github) ?? '';
    }

    final target = platform ?? defaultTargetPlatform;
    final platformUrl = switch (target) {
      TargetPlatform.android => manifest.channels.androidApk,
      TargetPlatform.windows => manifest.channels.windows,
      TargetPlatform.linux => manifest.channels.linux,
      TargetPlatform.macOS => manifest.channels.macos,
      _ => null,
    };
    final sanitizedPlatform = _sanitizeDownloadUrl(platformUrl);
    if (sanitizedPlatform != null) return sanitizedPlatform;
    return _sanitizeDownloadUrl(manifest.channels.github) ?? '';
  }

  @visibleForTesting
  static bool isAllowedDownloadUrl(String url) =>
      _sanitizeDownloadUrl(url) != null;

  static String? _sanitizeDownloadUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    if (!allowedDownloadHosts.contains(host)) return null;
    if (uri.hasPort && uri.port != 443) return null;
    return trimmed;
  }

  static String _messageForDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '检查更新超时',
      DioExceptionType.connectionError => '网络不可用，无法检查更新',
      DioExceptionType.badResponse => _messageForStatus(e.response?.statusCode),
      _ => '检查更新失败',
    };
  }

  static String _messageForStatus(int? statusCode) {
    return switch (statusCode) {
      404 => '更新清单不存在或不可公开访问',
      401 || 403 => '无权访问更新清单',
      final code when code != null && code >= 500 => '更新服务暂时不可用',
      final code when code != null => '检查更新失败（HTTP $code）',
      _ => '检查更新失败',
    };
  }

  /// GitHub raw often serves JSON as `text/plain`, so Dio may leave [data]
  /// as a [String] even with [ResponseType.json].
  static Map<String, dynamic> _coerceManifestMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        throw const FormatException('Empty manifest payload');
      }
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw FormatException(
        'Unexpected JSON root type: ${decoded.runtimeType}',
      );
    }
    throw FormatException(
      'Unexpected manifest payload type: ${data.runtimeType}',
    );
  }
}
