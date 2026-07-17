import 'dart:convert';

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
          'androidApk': 'https://example.com/app.apk',
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
          'androidApk': 'https://example.com/app.apk',
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
          'windows': 'https://example.com/app.zip',
        },
      });
      expect(
        UpdateCheckService.resolveDownloadUrl(
          m,
          distribution: 'github',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        'https://example.com/app.zip',
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
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.payload);

  final Map<String, dynamic> payload;

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
        Headers.contentTypeHeader: [Headers.jsonContentType],
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
