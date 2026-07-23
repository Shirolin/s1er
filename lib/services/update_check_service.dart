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
    List<String>? manifestUrls,
  })  : _manifestUrls = _buildManifestUrls(
          primary: manifestUrl ?? EnvConfig.updateManifestUrl,
          overrides: manifestUrls,
        ),
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
  final List<String> _manifestUrls;

  /// 国内可达的 jsDelivr 镜像（与 raw 同源文件）。
  static const String jsDelivrManifestUrl =
      'https://cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json';

  String get manifestUrl => _manifestUrls.first;

  @visibleForTesting
  List<String> get manifestUrls => List<String>.unmodifiable(_manifestUrls);

  static List<String> _buildManifestUrls({
    required String primary,
    List<String>? overrides,
  }) {
    if (overrides != null && overrides.isNotEmpty) {
      return overrides
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList(growable: false);
    }
    final urls = <String>[];
    final trimmed = primary.trim();
    if (trimmed.isNotEmpty) urls.add(trimmed);
    if (trimmed != jsDelivrManifestUrl) {
      urls.add(jsDelivrManifestUrl);
    }
    return urls;
  }

  Future<AppUpdateManifest> fetchManifest() async {
    Object? lastError;
    StackTrace? lastStack;
    var lastMessage = '检查更新失败';

    for (var i = 0; i < _manifestUrls.length; i++) {
      final url = _manifestUrls[i];
      try {
        final response = await _dio.get<dynamic>(url);
        return AppUpdateManifest.fromJson(_coerceManifestMap(response.data));
      } on DioException catch (e, st) {
        lastError = e;
        lastStack = st;
        lastMessage = _messageForDio(e);
        final isLast = i == _manifestUrls.length - 1;
        if (_isExpectedManifestMiss(e)) {
          talker.warning(
            'Fetch update manifest skipped ($url): $lastMessage',
          );
        } else if (isLast) {
          talker.handle(e, st, 'Fetch update manifest failed');
        } else {
          talker.warning(
            'Fetch update manifest failed ($url), trying next: $lastMessage',
          );
        }
      } on FormatException catch (e, st) {
        lastError = e;
        lastStack = st;
        lastMessage = '更新清单格式无效';
        final isLast = i == _manifestUrls.length - 1;
        if (isLast) {
          talker.handle(e, st, 'Parse update manifest failed');
          rethrow;
        }
        talker.warning(
          'Parse update manifest failed ($url), trying next: $e',
        );
      }
    }

    if (lastError is FormatException) {
      Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
    }
    throw UpdateCheckException(lastMessage, lastError);
  }

  /// 私有仓库 raw URL / 错链等：客户端无法公开拉取，属预期失败。
  static bool _isExpectedManifestMiss(DioException e) {
    if (e.type != DioExceptionType.badResponse) return false;
    final code = e.response?.statusCode;
    return code == 404 || code == 401 || code == 403;
  }

  /// 允许的升级下载 / 商店 / 清单镜像主机（https only）。
  static const Set<String> allowedDownloadHosts = {
    'github.com',
    'www.github.com',
    'raw.githubusercontent.com',
    'objects.githubusercontent.com',
    'cdn.jsdelivr.net',
    'play.google.com',
  };

  /// 允许用 [url_launcher] 打开的网盘主机（不用于 APK Dio 下载）。
  static const Set<String> allowedNetdiskHosts = {
    'pan.baidu.com',
    'yun.baidu.com',
    'www.aliyundrive.com',
    'www.alipan.com',
    'alipan.com',
    'www.quark.cn',
    'pan.quark.cn',
    'www.123pan.com',
    'www.123865.com',
    'www.lanzoui.com',
    'www.lanzoux.com',
    'wwwa.lanzoui.com',
  };

  /// 按设备 ABI 顺序解析 Android APK 直链（分架构 → universal），已 sanitize 去重。
  ///
  /// [supportedAbis] 为空时仅返回 universal（若有）。
  static List<String> resolveAndroidApkUrls(
    AppUpdateManifest manifest, {
    List<String> supportedAbis = const [],
  }) {
    final urls = <String>[];
    void addIfAllowed(String? raw) {
      final url = _sanitizeUrl(raw, allowedDownloadHosts);
      if (url == null || urls.contains(url)) return;
      urls.add(url);
    }

    final perAbi = manifest.channels.androidApks;
    if (perAbi != null && perAbi.isNotEmpty) {
      for (final abi in supportedAbis) {
        final key = abi.trim();
        if (key.isEmpty) continue;
        addIfAllowed(perAbi[key]);
      }
    }
    addIfAllowed(manifest.channels.androidApk);
    return List<String>.unmodifiable(urls);
  }

  /// 按分发渠道与平台解析下载 / 商店 URL。
  ///
  /// 仅返回通过主机白名单的 https URL；无一可用时返回空字符串。
  /// Android 时 [supportedAbis] 用于优先分架构包；返回列表首项。
  static String resolveDownloadUrl(
    AppUpdateManifest manifest, {
    String distribution = EnvConfig.distribution,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
    List<String> supportedAbis = const [],
  }) {
    final dist = distribution.trim().toLowerCase();
    if (dist == 'play') {
      // Play 渠道：只走商店或 GitHub Release 页，绝不回落 APK 直链。
      final play = _sanitizeUrl(
        manifest.channels.play,
        allowedDownloadHosts,
      );
      if (play != null) return play;
      return _sanitizeUrl(manifest.channels.github, allowedDownloadHosts) ?? '';
    }
    if (isWeb) {
      return _sanitizeUrl(manifest.channels.github, allowedDownloadHosts) ?? '';
    }

    final target = platform ?? defaultTargetPlatform;
    if (target == TargetPlatform.android) {
      final apkUrls = resolveAndroidApkUrls(
        manifest,
        supportedAbis: supportedAbis,
      );
      if (apkUrls.isNotEmpty) return apkUrls.first;
      return _sanitizeUrl(manifest.channels.github, allowedDownloadHosts) ?? '';
    }

    final platformUrl = switch (target) {
      TargetPlatform.windows => manifest.channels.windows,
      TargetPlatform.linux => manifest.channels.linux,
      TargetPlatform.macOS => manifest.channels.macos,
      _ => null,
    };
    final sanitizedPlatform = _sanitizeUrl(platformUrl, allowedDownloadHosts);
    if (sanitizedPlatform != null) return sanitizedPlatform;
    return _sanitizeUrl(manifest.channels.github, allowedDownloadHosts) ?? '';
  }

  /// 解析网盘外链；非法主机返回空字符串（UI 不展示网盘按钮）。
  static String resolveNetdiskUrl(AppUpdateManifest manifest) {
    return _sanitizeUrl(
          manifest.channels.androidNetdisk,
          allowedNetdiskHosts,
        ) ??
        '';
  }

  /// Android 应用内下载是否可用（非 Play、本机可解析出至少一条 APK 直链）。
  ///
  /// 以 [resolveAndroidApkUrls] 为准：须匹配本机 [supportedAbis] 或 universal。
  static bool canInAppAndroidDownload({
    required AppUpdateManifest manifest,
    String distribution = EnvConfig.distribution,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
    List<String> supportedAbis = const [],
  }) {
    if (isWeb) return false;
    if (distribution.trim().toLowerCase() == 'play') return false;
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android) return false;
    return resolveAndroidApkUrls(
      manifest,
      supportedAbis: supportedAbis,
    ).isNotEmpty;
  }

  static bool isAllowedDownloadUrl(String url) =>
      _sanitizeUrl(url, allowedDownloadHosts) != null;

  static bool isAllowedNetdiskUrl(String url) =>
      _sanitizeUrl(url, allowedNetdiskHosts) != null;

  static String? _sanitizeUrl(String? url, Set<String> allowedHosts) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    if (!allowedHosts.contains(host)) return null;
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
