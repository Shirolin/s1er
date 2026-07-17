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
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AppUpdateManifest.fromJson(data);
      }
      if (data is Map) {
        return AppUpdateManifest.fromJson(Map<String, dynamic>.from(data));
      }
      throw FormatException(
        'Unexpected manifest payload type: ${data.runtimeType}',
      );
    } on DioException catch (e, st) {
      talker.handle(e, st, 'Fetch update manifest failed');
      throw UpdateCheckException(_messageForDio(e), e);
    } on FormatException catch (e, st) {
      talker.handle(e, st, 'Parse update manifest failed');
      rethrow;
    }
  }

  /// 按分发渠道与平台解析下载 / 商店 URL。
  static String resolveDownloadUrl(
    AppUpdateManifest manifest, {
    String distribution = EnvConfig.distribution,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    final dist = distribution.trim().toLowerCase();
    if (dist == 'play') {
      final play = manifest.channels.play;
      if (play != null && play.isNotEmpty) return play;
    }
    if (isWeb) return manifest.channels.github;

    final target = platform ?? defaultTargetPlatform;
    final platformUrl = switch (target) {
      TargetPlatform.android => manifest.channels.androidApk,
      TargetPlatform.windows => manifest.channels.windows,
      TargetPlatform.linux => manifest.channels.linux,
      TargetPlatform.macOS => manifest.channels.macos,
      _ => null,
    };
    if (platformUrl != null && platformUrl.isNotEmpty) return platformUrl;
    return manifest.channels.github;
  }

  static String _messageForDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '检查更新超时',
      DioExceptionType.connectionError => '网络不可用，无法检查更新',
      _ => '检查更新失败',
    };
  }
}
