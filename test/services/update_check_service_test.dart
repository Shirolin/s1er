import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/app_exceptions.dart';
import 'package:s1er/models/app_update_manifest.dart';
import 'package:s1er/services/update_check_service.dart';

void main() {
  group('UpdateCheckService', () {
    test('fetchManifest parses JSON map', () async {
      final payload = {
        'latest': '1.1.0',
        'minSupported': '1.0.0',
        'notes': '',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };
      final dio = Dio()..httpClientAdapter = _JsonAdapter(payload);
      final service = UpdateCheckService(
        dio: dio,
        manifestUrl: 'https://example.com/latest.json',
      );
      final m = await service.fetchManifest();
      expect(m.latest, '1.1.0');
      expect(m.minSupported, '1.0.0');
    });

    test('fetchManifest parses text/plain JSON string (GitHub raw)', () async {
      final payload = {
        'latest': '1.2.0',
        'minSupported': '1.0.0',
        'notes': 'Beta',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          payload,
          contentType: 'text/plain; charset=utf-8',
        );
      final service = UpdateCheckService(
        dio: dio,
        manifestUrl: 'https://example.com/latest.json',
      );
      final m = await service.fetchManifest();
      expect(m.latest, '1.2.0');
      expect(m.notes, 'Beta');
    });

    test('fetchManifest wraps Dio errors', () async {
      final dio = Dio()..httpClientAdapter = _FailingAdapter();
      final service = UpdateCheckService(
        dio: dio,
        manifestUrl: 'https://example.com/latest.json',
      );
      expect(
        () => service.fetchManifest(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '检查更新超时',
          ),
        ),
      );
    });

    test('fetchManifest maps HTTP 404 to public-access message', () async {
      final dio = Dio()..httpClientAdapter = _StatusAdapter(404);
      final service = UpdateCheckService(
        dio: dio,
        manifestUrl: 'https://example.com/latest.json',
      );
      expect(
        () => service.fetchManifest(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '更新清单不存在或不可公开访问',
          ),
        ),
      );
    });

    test('resolveDownloadUrl prefers play when DISTRIBUTION=play', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'github': 'https://github.com/example/releases/latest',
          'play': 'https://play.google.com/store/apps/details?id=x',
          'androidApk':
              'https://github.com/example/releases/download/v1/app.apk',
        },
      });
      expect(
        UpdateCheckService.resolveDownloadUrl(
          m,
          distribution: 'play',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'https://play.google.com/store/apps/details?id=x',
      );
    });

    test('resolveDownloadUrl uses github on web', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'github': 'https://github.com/example/releases/latest',
          'androidApk':
              'https://github.com/example/releases/download/v1/app.apk',
        },
      });
      expect(
        UpdateCheckService.resolveDownloadUrl(
          m,
          distribution: 'github',
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'https://github.com/example/releases/latest',
      );
    });

    test('resolveDownloadUrl prefers platform package then github', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'github': 'https://github.com/example/releases/latest',
          'windows': 'https://github.com/example/releases/download/v1/app.zip',
        },
      });
      expect(
        UpdateCheckService.resolveDownloadUrl(
          m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        'https://github.com/example/releases/download/v1/app.zip',
      );
      expect(
        UpdateCheckService.resolveDownloadUrl(
          m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        'https://github.com/example/releases/latest',
      );
    });

    test('resolveDownloadUrl rejects non-allowlisted hosts', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'github': 'https://evil.example/releases/latest',
          'androidApk': 'https://evil.example/app.apk',
        },
      });
      expect(
        UpdateCheckService.resolveDownloadUrl(
          m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        '',
      );
      expect(
        UpdateCheckService.isAllowedDownloadUrl(
          'javascript:alert(1)',
        ),
        isFalse,
      );
    });

    test('fetchManifest falls back to next URL after 404', () async {
      final payload = {
        'latest': '3.0.0',
        'minSupported': '1.0.0',
        'notes': '',
        'publishedAt': '2026-07-19',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };
      final dio = Dio()
        ..httpClientAdapter = _FailoverAdapter(
          failUrl: 'https://primary.example/latest.json',
          payload: payload,
        );
      final service = UpdateCheckService(
        dio: dio,
        manifestUrls: const [
          'https://primary.example/latest.json',
          'https://cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json',
        ],
      );
      final m = await service.fetchManifest();
      expect(m.latest, '3.0.0');
    });

    test('resolveNetdiskUrl allows baidu and rejects others', () {
      final ok = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidNetdisk': 'https://pan.baidu.com/s/xxxx',
          'netdiskHint': '提取码：ab',
        },
      });
      expect(
        UpdateCheckService.resolveNetdiskUrl(ok),
        'https://pan.baidu.com/s/xxxx',
      );

      final bad = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidNetdisk': 'https://evil.example/share',
        },
      });
      expect(UpdateCheckService.resolveNetdiskUrl(bad), '');
      expect(
        UpdateCheckService.isAllowedNetdiskUrl('https://evil.example/x'),
        isFalse,
      );
    });

    test('resolveDownloadUrl prefers arm64-v8a APK when available', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidApk':
              'https://github.com/example/releases/download/v1/app-universal.apk',
          'androidArm64V8aApk':
              'https://github.com/example/releases/download/v1/app-arm64-v8a.apk',
        },
      });
      final v8aUrl = UpdateCheckService.resolveDownloadUrl(
        m,
        isWeb: false,
        platform: TargetPlatform.android,
        abiOverride: 'arm64-v8a',
      );
      expect(
        v8aUrl,
        'https://github.com/example/releases/download/v1/app-arm64-v8a.apk',
      );

      final fallbackUrl = UpdateCheckService.resolveDownloadUrl(
        m,
        isWeb: false,
        platform: TargetPlatform.android,
        abiOverride: 'armeabi-v7a',
      );
      expect(
        fallbackUrl,
        'https://github.com/example/releases/download/v1/app-universal.apk',
      );
    });

    test(
        'resolveDownloadUrl falls back to universal APK when specific APK host is disallowed',
        () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidApk':
              'https://github.com/example/releases/download/v1/app-universal.apk',
          'androidArm64V8aApk':
              'https://evil.example/releases/download/v1/app-arm64-v8a.apk',
        },
      });
      final url = UpdateCheckService.resolveDownloadUrl(
        m,
        isWeb: false,
        platform: TargetPlatform.android,
        abiOverride: 'arm64-v8a',
      );
      expect(
        url,
        'https://github.com/example/releases/download/v1/app-universal.apk',
      );
    });

    test('resolveDownloadUrl falls back to universal APK when ABI is null', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidApk':
              'https://github.com/example/releases/download/v1/app-universal.apk',
          'androidArm64V8aApk':
              'https://github.com/example/releases/download/v1/app-arm64-v8a.apk',
        },
      });
      final url = UpdateCheckService.resolveDownloadUrl(
        m,
        isWeb: false,
        platform: TargetPlatform.android,
        abiOverride: null,
      );
      expect(
        url,
        'https://github.com/example/releases/download/v1/app-universal.apk',
      );
    });

    test('canInAppAndroidDownload requires android apk and non-play', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidApk':
              'https://github.com/example/releases/download/v1/app.apk',
        },
      });
      expect(
        UpdateCheckService.canInAppAndroidDownload(
          manifest: m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
      expect(
        UpdateCheckService.canInAppAndroidDownload(
          manifest: m,
          distribution: 'play',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        UpdateCheckService.canInAppAndroidDownload(
          manifest: m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isFalse,
      );
    });

    test('canInAppWindowsDownload requires windows zip', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'windows': 'https://github.com/example/releases/download/v1/app.zip',
        },
      });
      expect(
        UpdateCheckService.canInAppWindowsDownload(
          manifest: m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        UpdateCheckService.canInAppDownload(
          manifest: m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        UpdateCheckService.canInAppWindowsDownload(
          manifest: m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        UpdateCheckService.canInAppWindowsDownload(
          manifest: m,
          distribution: 'play',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isFalse,
      );
    });

    test('canInAppWindowsDownload accepts zip path with query string', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'windows':
              'https://github.com/example/releases/download/v1/app.zip?token=abc',
        },
      });
      expect(
        UpdateCheckService.canInAppWindowsDownload(
          manifest: m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        UpdateCheckService.pathEndsWithZip(
          'https://example.com/pkg.zip?download=1',
        ),
        isTrue,
      );
      expect(
        UpdateCheckService.pathEndsWithZip(
          'https://example.com/pkg.zip.txt',
        ),
        isFalse,
      );
    });

    test('isGitHubReleaseAssetUrl detects APK release assets', () {
      expect(
        UpdateCheckService.isGitHubReleaseAssetUrl(
          'https://github.com/Shirolin/s1er/releases/download/v0.6.0/app.apk',
        ),
        isTrue,
      );
      expect(
        UpdateCheckService.isGitHubReleaseAssetUrl(
          'https://github.com/Shirolin/s1er/releases/latest',
        ),
        isFalse,
      );
    });

    test('resolveBrowserFallbackUrl prefers GitHub releases page for APKs', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'github': 'https://github.com/example/releases/latest',
          'androidApk':
              'https://github.com/example/releases/download/v1/app.apk',
        },
      });
      expect(
        UpdateCheckService.resolveBrowserFallbackUrl(
          m,
          downloadUrl:
              'https://github.com/example/releases/download/v1/app.apk',
        ),
        'https://github.com/example/releases/latest',
      );
      expect(
        UpdateCheckService.resolveBrowserFallbackUrl(
          m,
          downloadUrl: 'https://github.com/example/releases/latest',
        ),
        'https://github.com/example/releases/latest',
      );
    });

    test('apkFileNameFromUrl decodes plus and sanitizes', () {
      expect(
        UpdateCheckService.apkFileNameFromUrl(
          'https://github.com/Shirolin/s1er/releases/download/v0.6.0/'
          's1er-0.6.0%2B11-android-arm64-v8a.apk',
        ),
        's1er-0.6.0+11-android-arm64-v8a.apk',
      );
      expect(
        UpdateCheckService.apkFileNameFromUrl(
          'https://github.com/Shirolin/s1er/releases/latest',
        ),
        's1er-update.apk',
      );
    });

    // Kotlin 侧对照清单（MainActivity.allowedDownloadHosts）：
    // github.com, www.github.com, raw.githubusercontent.com,
    // objects.githubusercontent.com, release-assets.githubusercontent.com,
    // cdn.jsdelivr.net, play.google.com
    test('allowedDownloadHosts documents kotlin sync contract', () {
      const expectedHosts = {
        'github.com',
        'www.github.com',
        'raw.githubusercontent.com',
        'objects.githubusercontent.com',
        'release-assets.githubusercontent.com',
        'cdn.jsdelivr.net',
        'play.google.com',
      };
      expect(UpdateCheckService.allowedDownloadHosts, expectedHosts);
    });

    test('default manifestUrls include both raw and jsDelivr fallback', () {
      final service = UpdateCheckService(
        manifestUrl: UpdateCheckService.jsDelivrManifestUrl,
      );
      expect(
        service.manifestUrls,
        contains(UpdateCheckService.rawGithubManifestUrl),
      );
      expect(
        UpdateCheckService.isAllowedDownloadUrl(
          UpdateCheckService.jsDelivrManifestUrl,
        ),
        isTrue,
      );
    });

    test(
        'fetchManifest picks newest version even from slower source '
        '(Newest-Wins)', () async {
      // 慢源（raw）返回较新 3.0.0，快源（jsDelivr 旧缓存）返回旧 1.0.0。
      final payloadSlow = {
        'latest': '3.0.0',
        'minSupported': '1.0.0',
        'notes': 'Slow-new',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };
      final payloadFast = {
        'latest': '1.0.0',
        'minSupported': '1.0.0',
        'notes': 'Fast-stale',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };

      final dio = Dio()
        ..httpClientAdapter = _RaceAdapter(
          slowUrlSubstring: 'raw.githubusercontent.com',
          slowPayload: payloadSlow,
          fastPayload: payloadFast,
        );

      final service = UpdateCheckService(
        dio: dio,
        manifestUrls: [
          'https://raw.githubusercontent.com/Shirolin/s1er/main/docs/release/latest.json',
          'https://cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json',
        ],
      );

      final manifest = await service.fetchManifest();
      expect(manifest.latest, '3.0.0');
    });

    test(
        'fetchManifest keeps newest even when it arrives first '
        '(Newest-Wins)', () async {
      // 快源返回较新 2.0.0，慢源返回旧 1.0.0 → 仍取 2.0.0。
      final payloadSlow = {
        'latest': '1.0.0',
        'minSupported': '1.0.0',
        'notes': 'Slow-stale',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };
      final payloadFast = {
        'latest': '2.0.0',
        'minSupported': '1.0.0',
        'notes': 'Fast-new',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
        },
      };

      final dio = Dio()
        ..httpClientAdapter = _RaceAdapter(
          slowUrlSubstring: 'raw.githubusercontent.com',
          slowPayload: payloadSlow,
          fastPayload: payloadFast,
        );

      final service = UpdateCheckService(
        dio: dio,
        manifestUrls: [
          'https://raw.githubusercontent.com/Shirolin/s1er/main/docs/release/latest.json',
          'https://cdn.jsdelivr.net/gh/Shirolin/s1er@main/docs/release/latest.json',
        ],
      );

      final manifest = await service.fetchManifest();
      expect(manifest.latest, '2.0.0');
    });

    test('static docs/release/latest.json contains valid per-ABI APK URLs', () {
      final file = File('docs/release/latest.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final manifest = AppUpdateManifest.fromJson(json);

      expect(manifest.channels.androidArm64V8aApk, isNotNull);
      expect(manifest.channels.androidArm64V8aApk, contains('arm64-v8a'));
      expect(manifest.channels.androidArmeabiV7aApk, isNotNull);
      expect(manifest.channels.androidArmeabiV7aApk, contains('armeabi-v7a'));
      expect(manifest.channels.androidX8664Apk, isNotNull);
      expect(manifest.channels.androidX8664Apk, contains('x86_64'));
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(
    this.payload, {
    this.contentType = Headers.jsonContentType,
  });

  final Map<String, dynamic> payload;
  final String contentType;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionTimeout,
    );
  }
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: statusCode,
      ),
    );
  }
}

class _FailoverAdapter implements HttpClientAdapter {
  _FailoverAdapter({
    required this.failUrl,
    required this.payload,
  });

  final String failUrl;
  final Map<String, dynamic> payload;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() == failUrl ||
        options.path == failUrl ||
        options.uri.toString().startsWith(failUrl)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 404),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _RaceAdapter implements HttpClientAdapter {
  _RaceAdapter({
    required this.slowUrlSubstring,
    required this.slowPayload,
    required this.fastPayload,
  });

  final String slowUrlSubstring;
  final Map<String, dynamic> slowPayload;
  final Map<String, dynamic> fastPayload;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    if (url.contains(slowUrlSubstring)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return ResponseBody.fromString(
        jsonEncode(slowPayload),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(fastPayload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
